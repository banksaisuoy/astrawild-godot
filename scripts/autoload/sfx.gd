extends Node
## Sfx — central audio (v1.0.4).
## The game shipped effectively silent: the old player-side loader
## referenced non-existent ids, so only 2 of ~50 ArtSource WAVs ever
## played. This autoload builds the bus graph at boot, maps every event
## to the REAL files in res://assets/audio/, and offers flat +
## positional playback, looping zone ambience, per-weapon fire sounds,
## per-species vocals and zone-aware footsteps.

const BUSES := ["SFX", "Music", "Ambience", "UI"]

# event id -> wav file (stem, res://assets/audio/<stem>.wav)
const EVENTS := {
        # UI
        "ui_hover": "A_UI_Hover",
        "ui_click": "A_UI_Click",
        "ui_cancel": "A_UI_Cancel",
        "ui_confirm": "A_UI_Confirm",
        "ui_warning": "A_UI_Warning",
        "ui_craft_done": "A_UI_Craft_Done",
        "ui_research_done": "A_UI_Research_Done",
        # player
        "player_jump": "A_Player_Jump",
        "player_land": "A_Player_Land",
        "player_heartbeat": "A_Player_Heartbeat_Low",
        "scan_ping": "A_Player_Scan_Ping",
        # combat / feedback
        "impact_kinetic": "A_Weapon_Impact_Kinetic",
        "impact_energy": "A_Weapon_Impact_Energy",
        "capture_success": "A_Echo_Capture_Success",
        "legendary_wake": "A_Weapon_Singularity_Fire",
        "stinger_warning": "A_UI_Warning",
}

# ranged weapon item id -> fire event
const WEAPON_FIRE := {
        "Item_PulseLance": "A_Weapon_Arc_Fire",
        "Item_ArcCaster": "A_Weapon_Arc_Fire",
        "Item_Scrapshot": "A_Weapon_Scrap_Fire",
        "Item_PlasmaCharger": "A_Weapon_Plasma_Fire",
        "Item_LumenBeam": "A_Weapon_Plasma_Fire",
        "Item_MagrailDriver": "A_Weapon_Rail_Fire",
        "Item_StarlancePrototype": "A_Weapon_Singularity_Fire",
}

# species name -> vocal wav
const SPECIES_VOCALS := {
        "Bastionbeetle": "A_Echo_Bastionbeetle_Skitter",
        "Cindermule": "A_Echo_Cindermule_Grunt",
        "Deepdelver": "A_Echo_Deepdelver_Rumble",
        "Mistmender": "A_Echo_Mistmender_Chime",
        "Terraquill": "A_Echo_Terraquill_Call",
        "Voltpylon": "A_Echo_Voltpylon_Hum",
}

# zone key -> looping ambience wav
const ZONE_AMBIENCE := {
        "DawnFields": "A_Amb_Forest_Dawn",
        "Glimmerwood": "A_Amb_Forest_Dawn",
        "VerdantReach": "A_Amb_Forest_Dawn",
        "DuskMarsh": "A_Amb_Marsh_Dusk",
        "Frostveil": "A_Amb_Night_Crystal",
        "HollowApproach": "A_Amb_Night_Crystal",
        "AzureShallows": "A_Amb_Water_Lake",
        "TidebreakerIsles": "A_Amb_Water_Lake",
        "PearlseaReef": "A_Amb_Water_Lake",
        "EmberRidge": "A_Amb_Wind_Gentle",
        "Sunscar": "A_Amb_Wind_Gentle",
        "Stormcrest": "A_Amb_Wind_Gentle",
}

# zone key -> footstep wav
const ZONE_FOOTSTEPS := {
        "DawnFields": "A_Footstep_Grass",
        "Glimmerwood": "A_Footstep_Grass",
        "VerdantReach": "A_Footstep_Grass",
        "DuskMarsh": "A_Footstep_Grass",
        "Sunscar": "A_Footstep_Sand",
        "TidebreakerIsles": "A_Footstep_Sand",
        "AzureShallows": "A_Footstep_Water",
        "PearlseaReef": "A_Footstep_Water",
        "Frostveil": "A_Footstep_Stone",
        "EmberRidge": "A_Footstep_Stone",
        "Stormcrest": "A_Footstep_Stone",
        "HollowApproach": "A_Footstep_Stone",
}

var _streams := {}            # wav stem -> AudioStream
var _ambience_a: AudioStreamPlayer
var _ambience_b: AudioStreamPlayer
var _ambience_key := ""
var _ambience_flip := false
var _pool: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _last_heartbeat := 0.0


func _ready() -> void:
        _build_buses()
        _load_streams()
        _build_ambience_players()
        print("Sfx: %d streams, buses %s" % [_streams.size(), str(BUSES)])


# ------------------------------------------------------------------ buses --
func _build_buses() -> void:
        for bus_name in BUSES:
                if AudioServer.get_bus_index(bus_name) >= 0:
                        continue
                AudioServer.add_bus()
                var idx := AudioServer.bus_count - 1
                AudioServer.set_bus_name(idx, bus_name)
                AudioServer.set_bus_send(idx, "Master")


func _load_streams() -> void:
        var wanted := {}
        for ev in EVENTS:
                wanted[EVENTS[ev]] = true
        for stem in WEAPON_FIRE.values():
                wanted[stem] = true
        for stem in SPECIES_VOCALS.values():
                wanted[stem] = true
        for stem in ZONE_AMBIENCE.values():
                wanted[stem] = true
        for stem in ZONE_FOOTSTEPS.values():
                wanted[stem] = true
        for stem in wanted:
                var path := "res://assets/audio/%s.wav" % stem
                if ResourceLoader.exists(path):
                        var stream: AudioStream = load(path)
                        if stream:
                                _streams[stem] = stream


func _build_ambience_players() -> void:
        _ambience_a = AudioStreamPlayer.new()
        _ambience_a.bus = "Ambience"
        add_child(_ambience_a)
        _ambience_b = AudioStreamPlayer.new()
        _ambience_b.bus = "Ambience"
        add_child(_ambience_b)


# ------------------------------------------------------------------- play --
func play(event: String, vol_db: float = -10.0, pitch_jitter: float = 0.06) -> void:
        var stem: String = EVENTS.get(event, event)
        if not _streams.has(stem):
                return
        var p := _acquire_player()
        p.stream = _streams[stem]
        p.volume_db = vol_db
        p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
        p.play()


func play_at(event: String, pos: Vector3, vol_db: float = -8.0, max_dist: float = 26.0, pitch_jitter: float = 0.08) -> void:
        var stem: String = EVENTS.get(event, event)
        if not _streams.has(stem):
                return
        var p := _acquire_player_3d()
        p.stream = _streams[stem]
        p.position = pos
        p.volume_db = vol_db
        p.unit_size = 8.0
        p.max_db = 0.0
        p.max_distance = max_dist
        p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
        p.play()


func play_stem(stem: String, vol_db: float = -10.0) -> void:
        if _streams.has(stem):
                var p := _acquire_player()
                p.stream = _streams[stem]
                p.volume_db = vol_db
                p.play()


# -------------------------------------------------------------- semantics --
func play_weapon(item_id: String) -> void:
        var stem: String = WEAPON_FIRE.get(item_id, "")
        if stem != "":
                play_stem(stem, -8.0)


func play_species(species_name: String, pos: Vector3) -> void:
        var stem: String = SPECIES_VOCALS.get(species_name, "")
        if stem != "":
                var p := _acquire_player_3d()
                p.stream = _streams[stem]
                p.position = pos
                p.volume_db = -9.0
                p.unit_size = 10.0
                p.max_distance = 30.0
                p.play()


func play_footstep(zone_key: String) -> void:
        var stem: String = ZONE_FOOTSTEPS.get(zone_key, "A_Footstep_Grass")
        play_stem(stem, -18.0)


func play_ambience(zone_key: String) -> void:
        if zone_key == _ambience_key:
                return
        var stem: String = ZONE_AMBIENCE.get(zone_key, "A_Amb_Wind_Gentle")
        if not _streams.has(stem):
                return
        _ambience_key = zone_key
        # crossfade between the two looping players
        var incoming: AudioStreamPlayer
        var outgoing: AudioStreamPlayer
        if _ambience_flip:
                incoming = _ambience_a
                outgoing = _ambience_b
        else:
                incoming = _ambience_b
                outgoing = _ambience_a
        _ambience_flip = not _ambience_flip
        incoming.stream = _streams[stem]
        incoming.volume_db = -60.0
        incoming.play()
        var tw := create_tween()
        tw.tween_property(incoming, "volume_db", -14.0, 1.6)
        if outgoing.playing:
                tw.parallel().tween_property(outgoing, "volume_db", -60.0, 1.6)
                tw.chain().tween_callback(outgoing.stop)


func tick_heartbeat(hp_fraction: float) -> void:
        # called from Game._tick_survival — slow pulse when gravely wounded
        if hp_fraction > 0.25:
                return
        var now := Time.get_ticks_msec() / 1000.0
        if now - _last_heartbeat < 2.4:
                return
        _last_heartbeat = now
        play("player_heartbeat", -8.0, 0.02)


func stop_ambience() -> void:
        _ambience_key = ""
        for p in [_ambience_a, _ambience_b]:
                if p.playing:
                        var tw := create_tween()
                        tw.tween_property(p, "volume_db", -60.0, 0.8)
                        tw.tween_callback(p.stop)


# ------------------------------------------------------------------ pools --
func _acquire_player() -> AudioStreamPlayer:
        for p in _pool:
                if not p.playing:
                        return p
        var p := AudioStreamPlayer.new()
        p.bus = "SFX"
        add_child(p)
        _pool.append(p)
        return p


func _acquire_player_3d() -> AudioStreamPlayer3D:
        for p in _pool_3d:
                if not p.playing:
                        return p
        var p := AudioStreamPlayer3D.new()
        p.bus = "SFX"
        add_child(p)
        _pool_3d.append(p)
        return p
