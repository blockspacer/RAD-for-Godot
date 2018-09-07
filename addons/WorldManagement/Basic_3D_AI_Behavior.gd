extends KinematicBody



#AI Characteristics
export(bool) var AI_active = true
export(bool) var static_AI = false
export(int) var Team = 0
export(bool) var is_worker = false
export(int) var indifference = 10
export(float) var smellarea = 5
export(float) var heararea = 10
export(float) var health = 100
export(float) var speedfactor = 0.4
export(float) var hearing_precision = 2
export(float) var smelling_precision = 2
export(bool) var can_hear_workstations = true
export(bool) var can_smell_workstations = false

#time for timers
export(int) var timewaiting = 2


#Movement Values
export(bool) var flies = false
export(bool) var fixed_up = true
export(float) var weight = 1
export(float) var max_speed = 10
export(int) var turn_speed = 40
export(float) var accel = 19.0
export(float) var deaccel = 14.0
export(bool) var keep_jump_inertia = true
export(bool) var air_idle_deaccel = false
export(float) var JumpHeight = 7.0
export(float) var grav = 9.8

#Globals
var initialized = false
var on_workstation = false
var workstation_near = false
var player_near = false
var is_on_sight = false

#Vision colliders
var visible_obj1
var visible_obj2
var visible_obj3
var visible_obj4
var visible_obj5


var current_target
var up
var has_target = false
var workstation_pos = Vector3(0,0,0)
var margin_hearing = 0.0
var margin_smelling = 0.0
var position =Vector3(0,0,0)
var randposition =Vector3(0,0,0)
var linear_velocity = Vector3(0,0,0)
var gravity = Vector3(0,-grav,0)
var sharp_turn_threshold = 140
var jump_attempt = false
var jumping = false
var globaldelta = 0.0
var CHAR_SCALE = Vector3(1, 1, 1)
var is_moving = false



func _ready():
	add_child(preload("res://addons/WorldManagement/3D_AI.tscn").instance())
	$AI/Wait.wait_time = timewaiting
	$AI/Senses/SmellandHear/CollisionShape.shape.radius = smellarea
	$AI/Senses/Hear/CollisionShape.shape.radius = heararea
	var groups = get_groups()
	visible_obj1 = $AI/Senses/SmellandHear/Eyes
	visible_obj2 = $AI/Senses/SmellandHear/Eyes/Eyes2
	visible_obj3 = $AI/Senses/SmellandHear/Eyes/Eyes3
	visible_obj4 = $AI/Senses/SmellandHear/Eyes/Eyes4
	visible_obj5 = $AI/Senses/SmellandHear/Eyes/Eyes5
	set_process(true)

	Spatial_Routine()
	CHAR_SCALE = scale
	initialized = true
	current_target = null
	
func visible_colliding():
	if visible_obj1.is_colliding() or visible_obj2.is_colliding() or visible_obj3.is_colliding() or visible_obj4.is_colliding() or visible_obj5.is_colliding():
		return true
	else:
		return false


#Gets each object that should be considered for behavior and adds it to an array
func get_visible():
	var vis = []
	vis.append( visible_obj1)
	for a in range(1,5):
		if get("visible_obj"+str(a)).get_collider() != null:
			for x in get("visible_obj"+str(a)).get_collider().get_groups():
				if x == "Player" or "Workstation" or "AI":
					vis.append(get("visible_obj"+str(a)).get_collider())
			
	return vis


func Spatial_Routine():
	#idle()
	$AI/Wait.connect("timeout", self, "switch_waiting")
	#$AI/Hunt.connect("timeout", self, "Hunting")
	#$AI/Work.connect("timeout", self, "Work")
	$AI/Wander.connect("timeout", self, "new_position")
	$AI/NewSearch.connect("timeout", self, "reset_target")
	$AI/Senses/SmellandHear.connect("area_entered", self, "check_area")
	$AI/Senses/SmellandHear.connect("body_entered", self, "check_body")
	$AI/Senses/Hear.connect("body_entered", self, "check_sound")
	#Spatial_Routine()
	
	
func check_sound(object):
	pass
	
	
func reset_target():
	has_target = false 
	current_target = null

func switch_waiting():
	if is_moving:
		is_moving = false
		pass
	else:
		is_moving = true
		pass

func Work():
	if on_workstation:
		do_work()
	else:
		walk()

func Hunting():
	if player_near and not static_AI:
		Chase()
	else:
		if is_on_sight:
			attack()



func check_area(object):
	for x in object.get_groups():
		print(to_global(object.translation))
		print(object.translation)
		if can_smell_workstations:
			if x == "Workstation" and is_worker and indifference==10:
				current_target = object
				position = current_target.translation
				workstation_near = true
			if x == "Workstation" and is_worker and (indifference >= 1 and indifference <=5):
			#Killenemies()
				position = object.translation
				workstation_near = true
			if x == "Workstation" and is_worker and indifference == 0:
				#Killallenemies()
				position = object.translation
				workstation_near = true
	pass

func check_body(object):
	pass

func wander():
	if workstation_near and not has_target:
		#var vectorpos = (position-translation).normalized()
		Spatial_move_to(position, globaldelta)
	if not has_target:
		Spatial_move_to(randposition, globaldelta)
		#var vectorpos = (position-translation).normalized()
		Spatial_move_to(position, globaldelta)
	if has_target:
		Spatial_move_to(current_target.translation, globaldelta)

func Spatial_move_to(vector,delta):
	vector = vector - translation
	if not flies:
		linear_velocity += gravity*delta/weight

	if fixed_up:
		up = Vector3(0,1,0) # (up is against gravity)
	else:
		up = -gravity.normalized()
	var vertical_velocity = up.dot(linear_velocity) # Vertical velocity
	var horizontal_velocity = linear_velocity - up*vertical_velocity # Horizontal velocity
	var hdir = horizontal_velocity.normalized() # Horizontal direction
	var hspeed = horizontal_velocity.length()*speedfactor

	#look_at(vector, Vector3(0,1,0)) #Change to something that turns to the player or something they have to see

	var target_dir = (vector - up*vector.dot(up)).normalized()

	if (is_on_floor()): #Only lets the character change it's facing direction when it's on the floor.
		var sharp_turn = hspeed > 0.1 and rad2deg(acos(target_dir.dot(hdir))) > sharp_turn_threshold

		if (vector.length() > 0.1 and !sharp_turn):
			if (hspeed > 0.001):
				#linear_dir = linear_h_velocity/linear_vel
				#if (linear_vel > brake_velocity_limit and linear_dir.dot(ctarget_dir) < -cos(Math::deg2rad(brake_angular_limit)))
				#	brake = true
				#else
				hdir = RAD.adjust_facing(hdir, target_dir, delta, 1.0/hspeed*turn_speed, up)
				var facing_dir = hdir

			else:
				hdir = target_dir


			if (hspeed < max_speed):
				hspeed += accel*delta
		else:
			hspeed -= deaccel*delta
			if (hspeed < 0):
				hspeed = 0

		horizontal_velocity = hdir*hspeed


		var mesh_xform = get_transform()
		var facing_mesh = -mesh_xform.basis[0].normalized()
		facing_mesh = (facing_mesh - up*facing_mesh.dot(up)).normalized()

		if (hspeed>0):
			facing_mesh = RAD.adjust_facing(facing_mesh, target_dir, delta, 1.0/hspeed*turn_speed, up)
		var m3 = Basis(-facing_mesh, up, -facing_mesh.cross(up).normalized()).scaled(CHAR_SCALE)

		set_transform(Transform(m3, mesh_xform.origin))

		if (not jumping and jump_attempt):
			vertical_velocity = JumpHeight
			jumping = true
			#get_node("sound_jump").play()
	else:
		if (vector.length() > 0.1):
			horizontal_velocity += target_dir*accel*delta
			if (horizontal_velocity.length() > max_speed):
				horizontal_velocity = horizontal_velocity.normalized()*max_speed
		else:
			if (air_idle_deaccel):
				hspeed = hspeed - (deaccel*0.2)*delta
				if (hspeed < 0):
					hspeed = 0

				horizontal_velocity = hdir*hspeed

	if (jumping and vertical_velocity < 0):
		jumping = false
	if not flies:
		linear_velocity = horizontal_velocity + up*vertical_velocity
	else:
		linear_velocity = horizontal_velocity

	if (is_on_floor()):
		var movement_dir = linear_velocity

	linear_velocity = move_and_slide(linear_velocity,-gravity.normalized())

func _process(delta):
	var precision = 1 
	if AI_active:
		globaldelta = delta
		if is_moving:
			wander()
		else:
			Spatial_move_to(translation,delta)
		if initialized:
			AI_is_seeing()
		
		if workstation_near and can_smell_workstations:
			var vector_distance = sqrt(pow(translation.x-current_target.translation.x,2)+pow(translation.y-current_target.translation.y,2)+pow(translation.z-current_target.translation.z,2))
			precision = vector_distance/smelling_precision
			print(precision)
			if precision != null:
				print(precision)
				margin_smelling = rand_range(-precision,precision)
				position = Vector3(workstation_pos.x+margin_smelling,workstation_pos.y+margin_smelling,workstation_pos.z+margin_smelling)
		
		if (current_target != null):
			if (RAD.vec_distance(translation,current_target.translation) > heararea) or (visible_obj1.get_collider() != current_target):
				position = Vector3(current_target.translation.x, current_target.translation.y, current_target.translation.z) 
				$AI/NewSearch.start() #It's not looking at the target, has ten seconds to find it. 
			else: #It's looking at the target now. 
				if not $AI/NewSearch.is_stopped(): #Is it counting to change target? 
					$AI/NewSearch.stop() #Cancels the timer to look for another target

func new_position():
	if not has_target:
		randposition = Vector3(rand_range(-1,1),rand_range(-1,1),rand_range(-1,1))
	if $AI/Senses/SmellandHear/Checkheight.is_colliding():
		#new_position()
		pass
	

func AI_is_seeing():
	if visible_colliding():
		if get_visible() != null:
			for x in get_visible():
				for y in x.get_groups():
			 
			
					if y == "Workstation" and is_worker:
						if x.functional == true:
							current_target = x
							position = current_target.final_pos
							has_target = true
			
					if (y == "Player" or y == "AI")  and not x.Team == Team:
						current_target = x
						position = Vector3(current_target.translation.x, current_target.translation.y, current_target.translation.z) 
						has_target = true
					else:
						#if not has_target and (x.get_collider() is KinematicBody):
						#	var WorkPos = x.get_collider().translation
						#	Spatial_move_to(WorkPos, globaldelta)
						pass
func AI_Check_Target_State():
	if current_target.Health != 0:
		Attack()
		




func attack():
	pass

func aim_and_shoot():
	pass

func search():
	Spatial_move_to(Vector3(0.1,0.1,0.1),globaldelta)
	Spatial_move_to(Vector3(0.1,0.1,-0.1),globaldelta)
	Spatial_move_to(Vector3(-0.1,0.1,0.1),globaldelta)
	Spatial_move_to(Vector3(-0.1,0.1,-0.1),globaldelta)

	pass
