extends CanvasLayer

# ===== UI NODE REFERENCES =====
@onready var main_container: Control = $MainContainer
@onready var welcome_panel: PanelContainer = $MainContainer/WelcomePanel
@onready var login_panel: PanelContainer = $MainContainer/LoginPanel
@onready var signup_panel: PanelContainer = $MainContainer/SignupPanel

# Welcome Panel
@onready var show_login_from_welcome: Button = $MainContainer/WelcomePanel/VBox/LoginButton
@onready var show_signup_from_welcome: Button = $MainContainer/WelcomePanel/VBox/SignupButton
@onready var wallet_button_welcome: Button = $MainContainer/WelcomePanel/VBox/WalletButton
@onready var guest_button_welcome: Button = $MainContainer/WelcomePanel/VBox/GuestButton


# Login Panel
@onready var login_username: LineEdit = $MainContainer/LoginPanel/VBox/UsernameInput
@onready var login_password: LineEdit = $MainContainer/LoginPanel/VBox/PasswordInput
@onready var login_button: Button = $MainContainer/LoginPanel/VBox/LoginButton
@onready var back_from_login: Button = $MainContainer/LoginPanel/VBox/BackButton
@onready var login_status: Label = $MainContainer/LoginPanel/VBox/StatusLabel


# Signup Panel
@onready var signup_username: LineEdit = $MainContainer/SignupPanel/VBox/UsernameInput
@onready var signup_email: LineEdit = $MainContainer/SignupPanel/VBox/EmailInput
@onready var signup_password: LineEdit = $MainContainer/SignupPanel/VBox/PasswordInput
@onready var signup_confirm_password: LineEdit = $MainContainer/SignupPanel/VBox/ConfirmPasswordInput
@onready var signup_button: Button = $MainContainer/SignupPanel/VBox/SignupButton
@onready var back_from_signup: Button = $MainContainer/SignupPanel/VBox/BackButton
@onready var signup_status: Label = $MainContainer/SignupPanel/VBox/StatusLabel


# ===== CONSTANTS =====
const MIN_USERNAME_LENGTH = 3
const MAX_USERNAME_LENGTH = 20
const MIN_PASSWORD_LENGTH = 6
const SESSION_FILE = "user://session.save"
const USERS_FILE = "user://users.save"
const MAIN_MENU_SCENE = "res://PlayScene/play_scene.tscn"

# ===== SIGNALS =====
signal login_successful(user_data: Dictionary)
signal signup_successful(user_data: Dictionary)

# ===== STATE =====
enum PanelState { WELCOME, LOGIN, SIGNUP }
var current_panel: PanelState = PanelState.WELCOME


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_check_existing_session()


func _setup_ui() -> void:
	"""Initialize UI state and styling"""
	# Show welcome panel by default
	_show_panel(PanelState.WELCOME)
	
	# Setup input fields - Login
	login_username.placeholder_text = "Username or Email"
	login_password.placeholder_text = "Password"
	login_password.secret = true
	
	# Setup input fields - Signup
	signup_username.placeholder_text = "Username (3-20 characters)"
	signup_email.placeholder_text = "Email Address"
	signup_password.placeholder_text = "Password (min 6 characters)"
	signup_password.secret = true
	signup_confirm_password.placeholder_text = "Confirm Password"
	signup_confirm_password.secret = true
	
	# Set max lengths
	login_username.max_length = 50  # Allow for email addresses
	signup_username.max_length = MAX_USERNAME_LENGTH
	signup_email.max_length = 100
	
	# Clear status labels
	login_status.text = ""
	signup_status.text = ""
	
	# Optional: Add styling
	_apply_theme()


func _apply_theme() -> void:
	"""Apply custom theme/styling"""
	login_status.add_theme_color_override("font_color", Color.WHITE)
	signup_status.add_theme_color_override("font_color", Color.WHITE)


func _connect_signals() -> void:
	"""Connect all UI signals"""
	# Welcome Panel
	show_login_from_welcome.pressed.connect(_on_show_login_pressed)
	show_signup_from_welcome.pressed.connect(_on_show_signup_pressed)
	guest_button_welcome.pressed.connect(_on_guest_pressed)
	wallet_button_welcome.pressed.connect(_on_wallet_pressed)
	
	# Login Panel
	login_button.pressed.connect(_on_login_pressed)
	back_from_login.pressed.connect(_on_back_to_welcome_pressed)
	login_username.text_submitted.connect(_on_login_enter_pressed)
	login_password.text_submitted.connect(_on_login_enter_pressed)
	
	# Signup Panel
	signup_button.pressed.connect(_on_signup_pressed)
	back_from_signup.pressed.connect(_on_back_to_welcome_pressed)
	signup_username.text_submitted.connect(_on_signup_enter_pressed)
	signup_email.text_submitted.connect(_on_signup_enter_pressed)
	signup_password.text_submitted.connect(_on_signup_enter_pressed)
	signup_confirm_password.text_submitted.connect(_on_signup_enter_pressed)


func _check_existing_session() -> void:
	"""Check for existing active session"""
	if not FileAccess.file_exists(SESSION_FILE):
		return
	
	var file = FileAccess.open(SESSION_FILE, FileAccess.READ)
	if file == null:
		return
	
	var session_data = file.get_var()
	file.close()
	
	if typeof(session_data) != TYPE_DICTIONARY:
		return
	
	if session_data.get("logged_in", false):
		var user_id = session_data.get("user_id", "")
		if user_id != "":
			# Show welcome message on existing session
			_show_returning_user_message(user_id)
			await get_tree().create_timer(1.5).timeout
			_go_to_main_menu()


func _show_returning_user_message(user_id: String) -> void:
	"""Display message for returning user"""
	# You could add a label to welcome panel to show this
	print("👋 Welcome back, %s!" % user_id)


# ===== PANEL SWITCHING =====

func _show_panel(panel: PanelState) -> void:
	"""Switch between panels"""
	current_panel = panel
	
	# Hide all panels first
	welcome_panel.visible = false
	login_panel.visible = false
	signup_panel.visible = false
	
	# Show selected panel
	match panel:
		PanelState.WELCOME:
			welcome_panel.visible = true
			show_login_from_welcome.grab_focus()
		
		PanelState.LOGIN:
			login_panel.visible = true
			login_username.grab_focus()
			_clear_inputs(PanelState.LOGIN)
		
		PanelState.SIGNUP:
			signup_panel.visible = true
			signup_username.grab_focus()
			_clear_inputs(PanelState.SIGNUP)


func _on_show_login_pressed() -> void:
	_show_panel(PanelState.LOGIN)


func _on_show_signup_pressed() -> void:
	_show_panel(PanelState.SIGNUP)


func _on_back_to_welcome_pressed() -> void:
	_show_panel(PanelState.WELCOME)


# ===== LOGIN FUNCTIONALITY =====

func _on_login_enter_pressed(_text: String = "") -> void:
	"""Handle Enter key in login fields"""
	_on_login_pressed()


func _on_login_pressed() -> void:
	"""Handle login button press"""
	var username_or_email = login_username.text.strip_edges()
	var password = login_password.text
	
	# Validate inputs
	if username_or_email.is_empty():
		_show_status("Please enter your username or email.", true, PanelState.LOGIN)
		return
	
	if password.is_empty():
		_show_status("Please enter your password.", true, PanelState.LOGIN)
		return
	
	# Disable inputs during login
	_set_buttons_enabled(false, PanelState.LOGIN)
	_show_status("Logging in...", false, PanelState.LOGIN)
	
	# Simulate network delay
	await get_tree().create_timer(0.5).timeout
	
	# Try to verify user (supports both username and email)
	var user_data = _verify_user_login(username_or_email, password)
	
	if user_data != null:
		var username = user_data.get("username", username_or_email)
		_show_status("Login successful!", false, PanelState.LOGIN)
		
		# Save session
		if _save_user_session(username, "username", user_data.get("email", "")):
			login_successful.emit({
				"user_id": username,
				"login_type": "username",
				"email": user_data.get("email", "")
			})
			await get_tree().create_timer(0.5).timeout
			_go_to_main_menu()
		else:
			_show_status("Failed to save session.", true, PanelState.LOGIN)
			_set_buttons_enabled(true, PanelState.LOGIN)
	else:
		_show_status("Invalid username/email or password.", true, PanelState.LOGIN)
		_set_buttons_enabled(true, PanelState.LOGIN)


# ===== SIGNUP FUNCTIONALITY =====

func _on_signup_enter_pressed(_text: String = "") -> void:
	"""Handle Enter key in signup fields"""
	_on_signup_pressed()


func _on_signup_pressed() -> void:
	"""Handle signup button press"""
	var username = signup_username.text.strip_edges()
	var email = signup_email.text.strip_edges()
	var password = signup_password.text
	var confirm_password = signup_confirm_password.text
	
	# Validate username
	var validation_error = _validate_username(username)
	if validation_error != "":
		_show_status(validation_error, true, PanelState.SIGNUP)
		return
	
	# Validate email
	validation_error = _validate_email(email)
	if validation_error != "":
		_show_status(validation_error, true, PanelState.SIGNUP)
		return
	
	# Validate password
	validation_error = _validate_password(password)
	if validation_error != "":
		_show_status(validation_error, true, PanelState.SIGNUP)
		return
	
	# Check password match
	if password != confirm_password:
		_show_status("Passwords do not match.", true, PanelState.SIGNUP)
		return
	
	# Check if username exists
	if _user_exists(username):
		_show_status("Username already taken.", true, PanelState.SIGNUP)
		return
	
	# Check if email exists
	if _email_exists(email):
		_show_status("Email already registered.", true, PanelState.SIGNUP)
		return
	
	# Disable inputs during signup
	_set_buttons_enabled(false, PanelState.SIGNUP)
	_show_status("Creating account...", false, PanelState.SIGNUP)
	
	# Simulate network delay
	await get_tree().create_timer(0.5).timeout
	
	# Create account
	if _create_user(username, email, password):
		_show_status("Account created successfully!", false, PanelState.SIGNUP)
		
		# Save session and login
		if _save_user_session(username, "username", email):
			signup_successful.emit({
				"user_id": username,
				"login_type": "username",
				"email": email
			})
			await get_tree().create_timer(0.8).timeout
			_go_to_main_menu()
		else:
			_show_status("Account created but failed to login.", true, PanelState.SIGNUP)
			_set_buttons_enabled(true, PanelState.SIGNUP)
	else:
		_show_status("Failed to create account.", true, PanelState.SIGNUP)
		_set_buttons_enabled(true, PanelState.SIGNUP)


# ===== GUEST LOGIN =====

func _on_guest_pressed() -> void:
	"""Handle guest login"""
	_set_buttons_enabled(false, PanelState.WELCOME)
	
	var guest_id = "Guest_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)
	
	if _save_user_session(guest_id, "guest", ""):
		login_successful.emit({"user_id": guest_id, "login_type": "guest", "email": ""})
		_go_to_main_menu()
	else:
		print("Failed to create guest session.")
		_set_buttons_enabled(true, PanelState.WELCOME)


# ===== WALLET LOGIN =====

func _on_wallet_pressed() -> void:
	"""Handle wallet connection"""
	_set_buttons_enabled(false, PanelState.WELCOME)
	
	# TODO: Integrate with Solana/Honeycomb SDK
	await get_tree().create_timer(1.0).timeout
	
	var wallet_address = await _connect_wallet()
	
	if wallet_address != "":
		if _save_user_session(wallet_address, "wallet", ""):
			login_successful.emit({"user_id": wallet_address, "login_type": "wallet", "email": ""})
			_go_to_main_menu()
		else:
			print("Failed to save wallet session.")
			_set_buttons_enabled(true, PanelState.WELCOME)
	else:
		print("Wallet connection failed.")
		_set_buttons_enabled(true, PanelState.WELCOME)


func _connect_wallet() -> String:
	"""
	Placeholder for Solana wallet connection.
	Replace with actual Honeycomb SDK integration.
	"""
	# Simulate wallet connection (50% success for demo)
	var success = randi() % 2 == 0
	
	if success:
		return "Wallet" + str(randi() % 100000).pad_zeros(8) + "xyz"
	else:
		return ""


# ===== VALIDATION =====

func _validate_username(username: String) -> String:
	"""Validate username and return error message"""
	if username.is_empty():
		return "Please enter a username."
	
	if username.length() < MIN_USERNAME_LENGTH:
		return "Username must be at least %d characters." % MIN_USERNAME_LENGTH
	
	if username.length() > MAX_USERNAME_LENGTH:
		return "Username must be less than %d characters." % MAX_USERNAME_LENGTH
	
	# Check for invalid characters
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_-]+$")
	if not regex.search(username):
		return "Username can only contain letters, numbers, _ and -"
	
	return ""


func _validate_email(email: String) -> String:
	"""Validate email and return error message"""
	if email.is_empty():
		return "Please enter an email address."
	
	# Basic email validation
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	
	if not regex.search(email):
		return "Please enter a valid email address."
	
	return ""


func _validate_password(password: String) -> String:
	"""Validate password and return error message"""
	if password.is_empty():
		return "Please enter a password."
	
	if password.length() < MIN_PASSWORD_LENGTH:
		return "Password must be at least %d characters." % MIN_PASSWORD_LENGTH
	
	return ""


# ===== USER DATABASE MANAGEMENT =====

func _load_users_db() -> Dictionary:
	"""Load users database"""
	if not FileAccess.file_exists(USERS_FILE):
		return {}
	
	var file = FileAccess.open(USERS_FILE, FileAccess.READ)
	if file == null:
		push_error("Failed to open users file: " + str(FileAccess.get_open_error()))
		return {}
	
	var data = file.get_var()
	file.close()
	
	if typeof(data) == TYPE_DICTIONARY:
		return data
	else:
		return {}


func _save_users_db(users: Dictionary) -> bool:
	"""Save users database"""
	var file = FileAccess.open(USERS_FILE, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save users file: " + str(FileAccess.get_open_error()))
		return false
	
	file.store_var(users)
	file.close()
	return true


func _user_exists(username: String) -> bool:
	"""Check if username exists"""
	var users = _load_users_db()
	return users.has(username.to_lower())


func _email_exists(email: String) -> bool:
	"""Check if email is already registered"""
	var users = _load_users_db()
	var email_lower = email.to_lower()
	
	for user_key in users:
		var user_data = users[user_key]
		if user_data.get("email", "").to_lower() == email_lower:
			return true
	
	return false


func _create_user(username: String, email: String, password: String) -> bool:
	"""Create new user account"""
	var users = _load_users_db()
	var username_lower = username.to_lower()
	
	if users.has(username_lower):
		return false
	
	# Hash password (simple for now - use proper hashing in production)
	var password_hash = password.md5_text()
	
	users[username_lower] = {
		"username": username,  # Store original case
		"email": email,
		"password_hash": password_hash,
		"created_at": Time.get_unix_time_from_system(),
		"email_verified": false  # For future email verification
	}
	
	return _save_users_db(users)


func _verify_user_login(username_or_email: String, password: String) -> Dictionary:
	"""Verify user credentials - supports username or email"""
	var users = _load_users_db()
	var input_lower = username_or_email.to_lower()
	var password_hash = password.md5_text()
	
	# Try as username first
	if users.has(input_lower):
		var user_data = users[input_lower]
		if user_data.get("password_hash", "") == password_hash:
			return user_data
	
	# Try as email
	for user_key in users:
		var user_data = users[user_key]
		if user_data.get("email", "").to_lower() == input_lower:
			if user_data.get("password_hash", "") == password_hash:
				return user_data
	
	return {}


# ===== SESSION MANAGEMENT =====

func _save_user_session(user_id: String, login_type: String, email: String) -> bool:
	"""Save user session"""
	var session_data = {
		"user_id": user_id,
		"login_type": login_type,
		"email": email,
		"logged_in": true,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var file = FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save session: " + str(FileAccess.get_open_error()))
		return false
	
	file.store_var(session_data)
	file.close()
	
	print("✅ Session saved: %s (type: %s)" % [user_id, login_type])
	return true


# ===== UI HELPERS =====

func _show_status(message: String, is_error: bool, panel: PanelState) -> void:
	"""Display status message"""
	var status_label: Label
	
	match panel:
		PanelState.LOGIN:
			status_label = login_status
		PanelState.SIGNUP:
			status_label = signup_status
		_:
			return
	
	status_label.text = message
	status_label.modulate = Color.RED if is_error else Color.GREEN_YELLOW
	
	print(message)


func _set_buttons_enabled(enabled: bool, panel: PanelState) -> void:
	"""Enable or disable buttons"""
	match panel:
		PanelState.WELCOME:
			show_login_from_welcome.disabled = not enabled
			show_signup_from_welcome.disabled = not enabled
			guest_button_welcome.disabled = not enabled
			wallet_button_welcome.disabled = not enabled
		
		PanelState.LOGIN:
			login_button.disabled = not enabled
			back_from_login.disabled = not enabled
			login_username.editable = enabled
			login_password.editable = enabled
		
		PanelState.SIGNUP:
			signup_button.disabled = not enabled
			back_from_signup.disabled = not enabled
			signup_username.editable = enabled
			signup_email.editable = enabled
			signup_password.editable = enabled
			signup_confirm_password.editable = enabled


func _clear_inputs(panel: PanelState) -> void:
	"""Clear input fields"""
	match panel:
		PanelState.LOGIN:
			login_password.text = ""
			login_status.text = ""
		
		PanelState.SIGNUP:
			signup_password.text = ""
			signup_confirm_password.text = ""
			signup_status.text = ""


func _go_to_main_menu() -> void:
	"""Navigate to main menu"""
	var error = get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("Failed to load main menu: " + str(error))
		if current_panel != PanelState.WELCOME:
			_show_status("Failed to load game.", true, current_panel)
		_set_buttons_enabled(true, current_panel)


# ===== UTILITY FUNCTIONS =====

func get_user_by_email(email: String) -> Dictionary:
	"""Get user data by email address"""
	var users = _load_users_db()
	var email_lower = email.to_lower()
	
	for user_key in users:
		var user_data = users[user_key]
		if user_data.get("email", "").to_lower() == email_lower:
			return user_data
	
	return {}


func update_user_email(username: String, new_email: String) -> bool:
	"""Update user's email address"""
	var users = _load_users_db()
	var username_lower = username.to_lower()
	
	if not users.has(username_lower):
		return false
	
	# Check if new email is already in use
	if _email_exists(new_email):
		return false
	
	users[username_lower]["email"] = new_email
	users[username_lower]["email_verified"] = false
	
	return _save_users_db(users)
