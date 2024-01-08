extends CharacterBody2D

class_name Player

signal healthChanged
signal superChanged

#var yaga_shader = preload("res://shaders/rgb.gdshader")
@export var yaga_shader: ShaderMaterial
@export var yaga_bar: Sprite2D
@export var speed: int = 300
@export var attack_interval = 1
@export var wait_after_jump = 0
@onready var animations = $AnimationPlayer
@onready var collider = $Collider
@onready var jabAttackCollider = $AnimatedSprite2D/JabAttack/JabAttackCollider
@onready var jumpAttackCollider = $JumpAttack/JumpAttackCollider
@onready var camera = $Camera2D
@export var mainMusic: AudioStreamPlayer
@onready var GoGo = $GoGo

@export var maxHealth = 20
@onready var currentHealth: int = maxHealth

@export var maxSuper = 100
@onready var currentSuper: int = maxSuper

# для тряски
@export var randomStrength: float = 30
@export var shakeFade: float = 4

var rng = RandomNumberGenerator.new()

var shake_strength: float = 0.0

var lastAnimDirection: String = "Left"
var isDead: bool = false
var isTakeDamage: bool = false
var inAttackZone: bool = false
var isAttacking: bool = false
var isJumping: bool = false
var isSuper: bool = false
var waitNextJump: bool = false
var isShaking: bool = false
var isBossFightScene: bool = false
var y_before_jump: float

func _ready():
	GoGo.visible = false

func go_fucn():
	for i in range(5):
		GoGo.visible = true
		await get_tree().create_timer(.2).timeout
		GoGo.visible = false

func get_input():
	if isBossFightScene:
		velocity.x += 1
		velocity = velocity.normalized() * speed
		return
	velocity = Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		velocity.x += 1
	if Input.is_action_pressed("ui_left"):
		velocity.x -= 1
	if Input.is_action_pressed("ui_down") and !isJumping:
		velocity.y += 1
	if Input.is_action_pressed("ui_up") and !isJumping:
		velocity.y -= 1
	
	if Input.is_action_just_pressed("jump") and !waitNextJump:
		jump()
	
	
	if lastAnimDirection == "Right":
		jumpAttackCollider.position.x = $AnimatedSprite2D.position.x - 40
		jabAttackCollider.position.x = $AnimatedSprite2D.position.x - 40
	else:
		jumpAttackCollider.position.x = $AnimatedSprite2D.position.x + 10 
		jabAttackCollider.position.x = $AnimatedSprite2D.position.x + 10 
	
	if Input.is_action_just_pressed("jab_attack"):
		if isJumping:
			$AnimatedSprite2D.play("jump_attack")
			jumpAttackCollider.disabled = false
		
		if !isJumping:
			animations.play("jab_attack")
			isAttacking = true
			await animations.animation_finished
			#for i in range(attack_interval):
				#animations.play("idle")
				#await animations.animation_finished
			isAttacking = false
	elif Input.is_action_just_pressed("super_attack"):
		if !(currentSuper < 50):
			currentSuper -= 50
			superChanged.emit(currentSuper)
			animations.play("super")
			isSuper = true
			await animations.animation_finished
			#for i in range(attack_interval):
				#animations.play("idle")
				#await animations.animation_finished
			isSuper = false
	
	if isSuper:
		velocity = Vector2.ZERO
		if lastAnimDirection == "Right":
			velocity.x -= 10
		else:
			velocity.x += 10

	velocity = velocity.normalized() * speed

func updateAnimation():
	if isBossFightScene: return
	if isAttacking: return
	if isJumping: return
	if velocity == Vector2.ZERO:
		animations.play("idle")
		collider.position.x = $AnimatedSprite2D.position.x - 10
	else:
		animations.play("walk")
		if lastAnimDirection == "Left":
			$AnimatedSprite2D.flip_h = 0
		else:
			$AnimatedSprite2D.flip_h = 1
		
		var direction = "Left"
		if velocity.x < 0:
			direction = "Right"
		
		if velocity.x != 0:
			lastAnimDirection = direction
	
	collider.position.x = $AnimatedSprite2D.position.x


func _physics_process(delta):
	if isShaking:
		apply_shake()
		if shake_strength > 0:
			shake_strength = lerpf(shake_strength,0,shakeFade * delta)
			
			camera.offset = randomOffset()
		return
	if isTakeDamage: return
	if isDead: return
	if isAttacking: return
	
	get_input()
	move_and_slide()
	if isSuper: return
	updateAnimation()

func _on_hurt_box_area_entered(area):
	if area.is_in_group("bossFight"):
		animations.play("bossFight")
		isBossFightScene = true
		#camera.set_zoom(Vector2(0.5,0.5)) 
		await animations.animation_finished
		isBossFightScene = false
	if area.is_in_group("hitBoxBobik"):
		currentHealth -= 4
		healthChanged.emit(currentHealth)
		currentSuper += 10
		superChanged.emit(currentSuper)
		if currentHealth < 1:
			isShaking = true
			isDead = true
			animations.play("death")
			await animations.animation_finished
			isShaking = true
			isShaking = false
			await get_tree().create_timer(.4).timeout
			get_tree().reload_current_scene()
		else:
			isShaking = true
			isDead = true
			animations.play("death")
			await animations.animation_finished
			isShaking = true
			isShaking = false
			await get_tree().create_timer(.4).timeout
			animations.play("stay")
			await animations.animation_finished
			isDead = false
	if area.is_in_group("yaga"):
		yaga_activate()
	if area.is_in_group("heal"):
		currentHealth = 19
		healthChanged.emit(currentHealth)
	if !area.is_in_group("hitBox"): return
	currentHealth -= 1
	healthChanged.emit(currentHealth)
	currentSuper += 10
	superChanged.emit(currentSuper)
	if currentHealth < 1:
		isShaking = true
		isDead = true
		animations.play("death")
		await animations.animation_finished
		isShaking = true
		isShaking = false
		await get_tree().create_timer(.4).timeout
		get_tree().reload_current_scene()
	else:
		isTakeDamage = true
		animations.play("hurt")
		await animations.animation_finished
		isTakeDamage = false


func _on_jab_attack_area_entered(area):
	if !area.is_in_group("hurtBox"): return
	currentSuper += 5
	superChanged.emit(currentSuper)
	#print("Ударилл")

func jump():
	y_before_jump = $AnimatedSprite2D.position.y
	isJumping = true
	animations.play("jump")
	await animations.animation_finished
	isJumping = false
	jumpAttackCollider.disabled = true
	wait_next_jump()


func wait_next_jump():
	waitNextJump = true
	await get_tree().create_timer(waitNextJump).timeout
	waitNextJump = false

func apply_shake():
	shake_strength = randomStrength
	
func randomOffset() -> Vector2:
	return Vector2(rng.randf_range(-shake_strength, shake_strength), rng.randf_range(-shake_strength, shake_strength))

func yaga_activate():
	animations.speed_scale = 4
	speed *= 2
	mainMusic.pitch_scale = 1.5
	currentHealth = 200
	healthChanged.emit(currentHealth)
	
	# ЭФФЕКТЫ
	yaga_shader.set_shader_parameter("quality", 4)
	yaga_bar.visible = true
	await get_tree().create_timer(40).timeout
	yaga_shader.set_shader_parameter("quality", 0)
	yaga_bar.visible = false
	animations.speed_scale = 1
	speed /= 2
	
	mainMusic.pitch_scale = 1
	currentHealth = 19
	
	healthChanged.emit(currentHealth)


func _on_level_1_lvl_end():
	go_fucn()


func _on_level_2_lvl_end():
	go_fucn()


func _on_jump_attack_area_entered(area):
	if !area.is_in_group("hurtBox"): return
	currentSuper += 5
	superChanged.emit(currentSuper)
