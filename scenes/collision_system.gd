extends Node
class_name CollisionSystem

@export var max_checks_per_frame: int = 20000 # safety for later

func _process(_delta: float) -> void:
  var bullets := get_tree().get_nodes_in_group("bullets")
  var enemies := get_tree().get_nodes_in_group("enemies")

  var checks := 0
  for b: Bullet in bullets:
    if not is_instance_valid(b) or not b.visible:
      continue
    if not (b is Bullet):
      continue

    var bpos: Vector2 = b.position
    var br: float = b.hit_radius_px * b.scale.x

    for e: Enemy in enemies:
      checks += 1
      if checks > max_checks_per_frame:
        return

      if not is_instance_valid(e) or not e.visible:
        continue
      if not (e is Enemy):
        continue

      # var epos: Vector2 = e.position
      # var er: float = e.hit_radius_px * e.scale.x
 
      # if bpos.distance_to(epos) <= (br + er):
      #   (e as Enemy).take_hit((b as Bullet).damage)
      #   b.queue_free()
      #   break

      var bullet_hit_radius_px: float = b.hit_radius_px
      var player_hurt_radius_px: float = e.hit_radius_px
      var hit = b.world_pos.distance_to(e.world_pos) < bullet_hit_radius_px + player_hurt_radius_px
      if hit:
        e.take_hit((b as Bullet).damage)
        b.queue_free()
        break


  # Enemy bullets -> Player
  var players := get_tree().get_nodes_in_group("player")
  if players.size() == 0:
    return
  var player := players[0] as Player
  if player == null or not player.can_be_hit():
    return

  var enemy_bullets := get_tree().get_nodes_in_group("enemy_bullets")
  for eb in enemy_bullets:
    if not is_instance_valid(eb) or not eb.visible:
      continue
    if not (eb is EnemyBullet):
      continue

#    var bpos: Vector2 = eb.position
#    var br: float = (eb as EnemyBullet).hit_radius_px * eb.scale.x
#    var pr: float = player.hurt_radius_px
#
#    if bpos.distance_to(player.position) <= (br + pr):
#      player.take_hit((eb as EnemyBullet).damage)
#      eb.queue_free()
#      break
    
    var enemy_bullet = eb as EnemyBullet
    var bullet_hit_radius_px: float = (eb as EnemyBullet).hit_radius_px
    var player_hurt_radius_px: float = player.hurt_radius_px
    var hit = player.world_pos.distance_to(enemy_bullet.world_pos) < bullet_hit_radius_px + player_hurt_radius_px
    if hit:
      player.take_hit((eb as EnemyBullet).damage)
      eb.queue_free()
      break
