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
const MAX_LOGIN_ATTEMPTS = 5
const LOCKOUT_TIME = 300  # 5 minutes in seconds

enum SignupState { FORM, OTP_PENDING }

# ===== SIGNALS =====
signal login_successful(user_data: Dictionary)
signal signup_successful(user_data: Dictionary)

# ===== STATE =====
enum PanelState { WELCOME, LOGIN, SIGNUP }
var current_panel: PanelState = PanelState.WELCOME
var _login_attempts: Dictionary = {}  # Track failed login attempts
var _signup_state: SignupState = SignupState.FORM
var _pending_signup_email: String = ""
var _pending_signup_password: String = ""
var _pending_signup_username: String = ""
var _default_signup_button_text: String = ""
var _default_confirm_placeholder: String = ""


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_check_existing_session()


func _setup_ui() -> void:
	"""Initialize UI state and styling"""
	# Show welcome panel by default
	_show_panel(PanelState.WELCOME)
	
	# Setup input fields - Login
	login_username.placeholder_text = "Email"
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
	login_username.max_length = 100  # Allow for email addresses
	signup_username.max_length = MAX_USERNAME_LENGTH
	signup_email.max_length = 100
	
	# Clear status labels
	login_status.text = ""
	signup_status.text = ""
	
	_default_signup_button_text = signup_button.text
	_default_confirm_placeholder = signup_confirm_password.placeholder_text
	
	# Optional: Add styling
	_apply_theme()


func _apply_theme() -> void:
	"""Apply custom theme/styling"""
	login_status.add_theme_color_override("font_color", Color.WHITE)
	signup_status.add_theme_color_override("font_color", Color.WHITE)



func _process_login_payload(email: String, payload: Dictionary, raw_response: Dictionary = {}, display_name_override: String = "", extra_session_fields: Dictionary = {}) -> Dictionary:
	var user_info: Dictionary = {}
	if payload.has("user") and typeof(payload["user"]) == TYPE_DICTIONARY:
		user_info = payload["user"]
	
	var access_token: String = str(payload.get("accessToken", ""))
	var refresh_token: String = str(payload.get("refreshToken", ""))
	
	var display_name: String = display_name_override
	if display_name.is_empty():
		if user_info.has("username") and typeof(user_info["username"]) == TYPE_STRING:
			display_name = user_info["username"]
		elif user_info.has("email") and typeof(user_info["email"]) == TYPE_STRING:
			display_name = user_info["email"]
		else:
			display_name = email
	
	var extra_data: Dictionary = {
		"access_token": access_token,
		"refresh_token": refresh_token,
		"profile": user_info,
		"auth_payload": payload,
		"display_name": display_name
	}
	
	if not raw_response.is_empty():
		extra_data["raw_response"] = raw_response
	
	for key in extra_session_fields.keys():
		extra_data[key] = extra_session_fields[key]
	
	var saved := _save_user_session(display_name, "vorld", email, extra_data)
	
	return {
		"saved": saved,
		"display_name": display_name,
		"access_token": access_token,
		"profile": user_info
	}


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
			if _signup_state != SignupState.FORM:
				_reset_signup_flow()
			signup_panel.visible = true
			signup_username.grab_focus()
			_clear_inputs(PanelState.SIGNUP)


func _on_show_login_pressed() -> void:
	_show_panel(PanelState.LOGIN)


func _on_show_signup_pressed() -> void:
	_show_panel(PanelState.SIGNUP)


func _on_back_to_welcome_pressed() -> void:
	if _signup_state == SignupState.OTP_PENDING:
		_reset_signup_flow()
	_show_panel(PanelState.WELCOME)


# ===== LOGIN FUNCTIONALITY =====

func _on_login_enter_pressed(_text: String = "") -> void:
	"""Handle Enter key in login fields"""
	_on_login_pressed()


func _on_login_pressed() -> void:
	"""Handle login button press"""
	var email = login_username.text.strip_edges()
	var password = login_password.text
	
	# Validate inputs
	if email.is_empty():
		_show_status("Please enter your email address.", true, PanelState.LOGIN)
		return
	
	var email_error = _validate_email(email)
	if email_error != "":
		_show_status(email_error, true, PanelState.LOGIN)
		return
	
	if password.is_empty():
		_show_status("Please enter your password.", true, PanelState.LOGIN)
		return
	
	# Check rate limiting
	if not _check_rate_limit(email):
		var time_remaining = _get_lockout_time_remaining(email)
		_show_status("Too many failed attempts. Try again in %d minutes." % ceil(time_remaining / 60.0), true, PanelState.LOGIN)
		return
	
	# Disable inputs during login
	_set_buttons_enabled(false, PanelState.LOGIN)
	_show_status("Logging in...", false, PanelState.LOGIN)
	
	var response := await VorldClient.login(email, password)
	
	if response.get("ok", false):
		_clear_login_attempts(email)
		
		var payload: Dictionary = response.get("payload", {})
		var login_result: Dictionary = _process_login_payload(email, payload, response.get("data", {}))
		
		if login_result.get("saved", false):
			_show_status("Login successful!", false, PanelState.LOGIN)
			var sync_response := await VorldClient.sync_session(login_result.get("access_token", ""))
			if not sync_response.get("ok", true):
				var sync_error := VorldClient.get_error_message(sync_response, "Failed to synchronize bridge session.")
				push_warning("Bridge sync warning: %s" % sync_error)
			login_successful.emit({
				"user_id": login_result.get("display_name", email),
				"login_type": "vorld",
				"email": email,
				"access_token": login_result.get("access_token", ""),
				"profile": login_result.get("profile", {})
			})
			await get_tree().create_timer(0.5).timeout
			_go_to_main_menu()
		else:
			_show_status("Failed to save session.", true, PanelState.LOGIN)
			_set_buttons_enabled(true, PanelState.LOGIN)
	else:
		_record_failed_attempt(email)
		
		var message := VorldClient.get_error_message(response, "Login failed.")
		
		var attempts_left = MAX_LOGIN_ATTEMPTS - _get_attempt_count(email)
		if attempts_left > 0:
			message = "%s %d attempts remaining." % [message, attempts_left]
		else:
			message = "%s Account locked. Too many failed attempts." % message
		
		_show_status(message, true, PanelState.LOGIN)
		_set_buttons_enabled(true, PanelState.LOGIN)


# ===== SIGNUP FUNCTIONALITY =====

func _on_signup_enter_pressed(_text: String = "") -> void:
	"""Handle Enter key in signup fields"""
	_on_signup_pressed()


func _on_signup_pressed() -> void:
	"""Handle signup button press"""
	match _signup_state:
		SignupState.FORM:
			await _submit_signup_form()
		SignupState.OTP_PENDING:
			await _submit_signup_otp()


func _submit_signup_form() -> void:
	var username = signup_username.text.strip_edges()
	var email = signup_email.text.strip_edges()
	var password = signup_password.text
	var confirm_password = signup_confirm_password.text
	
	var validation_error = _validate_username(username)
	if validation_error != "":
		_show_status(validation_error, true, PanelState.SIGNUP)
		return
	
	validation_error = _validate_email(email)
	if validation_error != "":
		_show_status(validation_error, true, PanelState.SIGNUP)
		return
	
	validation_error = _validate_password(password)
	if validation_error != "":
		_show_status(validation_error, true, PanelState.SIGNUP)
		return
	
	if password != confirm_password:
		_show_status("Passwords do not match.", true, PanelState.SIGNUP)
		return
	
	_set_buttons_enabled(false, PanelState.SIGNUP)
	_show_status("Requesting verification code...", false, PanelState.SIGNUP)
	
	var response := await VorldClient.request_otp(email, password)
	
	if not response.get("ok", false):
		var error_message := VorldClient.get_error_message(response, "Failed to request OTP.")
		_show_status(error_message, true, PanelState.SIGNUP)
		_set_buttons_enabled(true, PanelState.SIGNUP)
		return
	
	var payload: Dictionary = response.get("payload", {})
	var requires_otp: bool = bool(payload.get("requiresOTP", true))
	var extra_fields: Dictionary = {"preferred_username": username}
	
	if not requires_otp and payload.has("accessToken"):
		_show_status("Account ready! Logging you in...", false, PanelState.SIGNUP)
		var login_response := await VorldClient.login(email, password)
		
		if login_response.get("ok", false):
			var login_result: Dictionary = _process_login_payload(email, login_response.get("payload", {}), login_response.get("data", {}), "", extra_fields)
			if login_result.get("saved", false):
				var sync_response := await VorldClient.sync_session(login_result.get("access_token", ""))
				if not sync_response.get("ok", true):
					var sync_error := VorldClient.get_error_message(sync_response, "Failed to synchronize bridge session.")
					push_warning("Bridge sync warning: %s" % sync_error)
				signup_successful.emit({
					"user_id": login_result.get("display_name", email),
					"login_type": "vorld",
					"email": email,
					"access_token": login_result.get("access_token", ""),
					"profile": login_result.get("profile", {})
				})
				await get_tree().create_timer(0.5).timeout
				_reset_signup_flow()
				_go_to_main_menu()
			else:
				_show_status("Account created but failed to save session.", true, PanelState.SIGNUP)
				_set_buttons_enabled(true, PanelState.SIGNUP)
		else:
			var login_error := VorldClient.get_error_message(login_response, "Login failed.")
			_show_status(login_error, true, PanelState.SIGNUP)
			_set_buttons_enabled(true, PanelState.SIGNUP)
		return
	
	_pending_signup_email = email
	_pending_signup_password = password
	_pending_signup_username = username
	_signup_state = SignupState.OTP_PENDING
	
	signup_button.text = "Verify OTP"
	signup_password.editable = false
	signup_username.editable = false
	signup_email.editable = false
	signup_confirm_password.editable = true
	signup_confirm_password.text = ""
	signup_confirm_password.placeholder_text = "Enter 6-digit OTP"
	signup_confirm_password.secret = false
	
	_show_status("OTP sent to %s. Enter the code and press Verify." % email, false, PanelState.SIGNUP)
	_set_buttons_enabled(true, PanelState.SIGNUP)


func _submit_signup_otp() -> void:
	var otp = signup_confirm_password.text.strip_edges()
	
	if otp.is_empty():
		_show_status("Please enter the 6-digit OTP sent to your email.", true, PanelState.SIGNUP)
		return
	
	if otp.length() != 6:
		_show_status("OTP should be a 6-digit code.", true, PanelState.SIGNUP)
		return
	
	_set_buttons_enabled(false, PanelState.SIGNUP)
	_show_status("Verifying OTP...", false, PanelState.SIGNUP)
	
	var response := await VorldClient.verify_otp(_pending_signup_email, otp)
	
	if not response.get("ok", false):
		var error_message := VorldClient.get_error_message(response, "Failed to verify OTP.")
		_show_status(error_message, true, PanelState.SIGNUP)
		_set_buttons_enabled(true, PanelState.SIGNUP)
		return
	
	_show_status("OTP verified! Logging you in...", false, PanelState.SIGNUP)
	
	var login_response := await VorldClient.login(_pending_signup_email, _pending_signup_password)
	
	if not login_response.get("ok", false):
		var login_error := VorldClient.get_error_message(login_response, "Login failed after verification.")
		_show_status(login_error, true, PanelState.SIGNUP)
		_set_buttons_enabled(true, PanelState.SIGNUP)
		return
	
	var extra_fields: Dictionary = {}
	if not _pending_signup_username.is_empty():
		extra_fields["preferred_username"] = _pending_signup_username
	
	var login_result := _process_login_payload(_pending_signup_email, login_response.get("payload", {}), login_response.get("data", {}), _pending_signup_username, extra_fields)
	
	if not login_result.get("saved", false):
		_show_status("Account verified but failed to save session.", true, PanelState.SIGNUP)
		_set_buttons_enabled(true, PanelState.SIGNUP)
		return
	
	var sync_response := await VorldClient.sync_session(login_result.get("access_token", ""))
	if not sync_response.get("ok", true):
		var sync_error := VorldClient.get_error_message(sync_response, "Failed to synchronize bridge session.")
		push_warning("Bridge sync warning: %s" % sync_error)
	
	signup_successful.emit({
		"user_id": login_result.get("display_name", _pending_signup_email),
		"login_type": "vorld",
		"email": _pending_signup_email,
		"access_token": login_result.get("access_token", ""),
		"profile": login_result.get("profile", {})
	})
	
	await get_tree().create_timer(0.5).timeout
	_reset_signup_flow()
	_go_to_main_menu()


func _reset_signup_flow() -> void:
	_signup_state = SignupState.FORM
	_pending_signup_email = ""
	_pending_signup_password = ""
	_pending_signup_username = ""
	
	signup_button.text = _default_signup_button_text
	signup_username.editable = true
	signup_email.editable = true
	signup_password.editable = true
	signup_confirm_password.editable = true
	signup_confirm_password.placeholder_text = _default_confirm_placeholder
	signup_confirm_password.secret = true
	signup_password.text = ""
	signup_confirm_password.text = ""
	
	_set_buttons_enabled(true, PanelState.SIGNUP)
	_show_status("", false, PanelState.SIGNUP)


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


# ===== RATE LIMITING =====

func _check_rate_limit(identifier: String) -> bool:
	"""Check if user is rate limited"""
	var identifier_lower = identifier.to_lower()
	
	if not _login_attempts.has(identifier_lower):
		return true
	
	var attempts = _login_attempts[identifier_lower]
	if attempts.count >= MAX_LOGIN_ATTEMPTS:
		var time_passed = Time.get_unix_time_from_system() - attempts.first_attempt
		if time_passed < LOCKOUT_TIME:
			return false
		else:
			# Lockout period expired, clear attempts
			_login_attempts.erase(identifier_lower)
	
	return true


func _record_failed_attempt(identifier: String) -> void:
	"""Record a failed login attempt"""
	var identifier_lower = identifier.to_lower()
	var current_time = Time.get_unix_time_from_system()
	
	if not _login_attempts.has(identifier_lower):
		_login_attempts[identifier_lower] = {
			"count": 1,
			"first_attempt": current_time,
			"last_attempt": current_time
		}
	else:
		var attempts = _login_attempts[identifier_lower]
		
		# Reset if lockout period has passed
		if current_time - attempts.first_attempt >= LOCKOUT_TIME:
			_login_attempts[identifier_lower] = {
				"count": 1,
				"first_attempt": current_time,
				"last_attempt": current_time
			}
		else:
			attempts.count += 1
			attempts.last_attempt = current_time


func _clear_login_attempts(identifier: String) -> void:
	"""Clear failed login attempts on successful login"""
	var identifier_lower = identifier.to_lower()
	if _login_attempts.has(identifier_lower):
		_login_attempts.erase(identifier_lower)


func _get_attempt_count(identifier: String) -> int:
	"""Get number of failed attempts for identifier"""
	var identifier_lower = identifier.to_lower()
	if _login_attempts.has(identifier_lower):
		return _login_attempts[identifier_lower].count
	return 0


func _get_lockout_time_remaining(identifier: String) -> float:
	"""Get remaining lockout time in seconds"""
	var identifier_lower = identifier.to_lower()
	if not _login_attempts.has(identifier_lower):
		return 0.0
	
	var attempts = _login_attempts[identifier_lower]
	var time_passed = Time.get_unix_time_from_system() - attempts.first_attempt
	return max(0.0, LOCKOUT_TIME - time_passed)


# ===== PASSWORD HASHING =====

func _generate_salt() -> String:
	"""Generate a random salt for password hashing"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var salt = ""
	for i in range(16):
		salt += String.chr(rng.randi_range(33, 126))
	return salt.sha256_text()


func _hash_password(password: String, salt: String) -> String:
	"""Hash password with salt using SHA-256 (multiple rounds)"""
	var hash = password + salt
	# Apply SHA-256 multiple times for better security (1000 rounds)
	for i in range(1000):
		hash = hash.sha256_text()
	return hash


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
	"""Create new user account with secure password storage"""
	var users = _load_users_db()
	var username_lower = username.to_lower()
	
	if users.has(username_lower):
		return false
	
	# Generate salt and hash password securely
	var salt = _generate_salt()
	var password_hash = _hash_password(password, salt)
	
	users[username_lower] = {
		"username": username,  # Store original case
		"email": email,
		"password_hash": password_hash,
		"salt": salt,  # Store salt with user data
		"created_at": Time.get_unix_time_from_system(),
		"email_verified": false  # For future email verification
	}
	
	return _save_users_db(users)


func _verify_user_login(username_or_email: String, password: String) -> Dictionary:
	"""Verify user credentials with salted hash - supports username or email"""
	var users = _load_users_db()
	var input_lower = username_or_email.to_lower()
	
	var user_data: Dictionary
	
	# Try as username first
	if users.has(input_lower):
		user_data = users[input_lower]
	else:
		# Try as email
		for user_key in users:
			var current_user = users[user_key]
			if current_user.get("email", "").to_lower() == input_lower:
				user_data = current_user
				break
	
	# Verify password if user found
	if not user_data.is_empty():
		var salt = user_data.get("salt", "")
		var stored_hash = user_data.get("password_hash", "")
		var input_hash = _hash_password(password, salt)
		
		if input_hash == stored_hash:
			return user_data
	
	return {}  # Return empty dict on failure


# ===== SESSION MANAGEMENT =====

func _save_user_session(user_id: String, login_type: String, email: String, extra_data: Dictionary = {}) -> bool:
	"""Save user session"""
	var session_data = {
		"user_id": user_id,
		"login_type": login_type,
		"email": email,
		"logged_in": true,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	for key in extra_data.keys():
		session_data[key] = extra_data[key]
	
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
			var allow_form_edit := enabled and _signup_state == SignupState.FORM
			signup_username.editable = allow_form_edit
			signup_email.editable = allow_form_edit
			signup_password.editable = allow_form_edit
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


func update_user_password(username: String, old_password: String, new_password: String) -> bool:
	"""Update user's password"""
	var users = _load_users_db()
	var username_lower = username.to_lower()
	
	if not users.has(username_lower):
		return false
	
	var user_data = users[username_lower]
	
	# Verify old password
	var old_salt = user_data.get("salt", "")
	var stored_hash = user_data.get("password_hash", "")
	var old_hash = _hash_password(old_password, old_salt)
	
	if old_hash != stored_hash:
		return false
	
	# Generate new salt and hash
	var new_salt = _generate_salt()
	var new_hash = _hash_password(new_password, new_salt)
	
	users[username_lower]["password_hash"] = new_hash
	users[username_lower]["salt"] = new_salt
	
	return _save_users_db(users)
