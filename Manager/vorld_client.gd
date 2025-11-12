extends Node

const DEFAULT_API_BASE_URL := "http://localhost:9080"
const DEFAULT_API_PATH := "/api"
const API_TIMEOUT_SECONDS := 30.0

var api_base_url: String = DEFAULT_API_BASE_URL
var api_path_prefix: String = DEFAULT_API_PATH
var stream_url: String = ""
var auth_token: String = ""

func _ready() -> void:
	configure_from_settings()


func configure(base_url: String = "", path_prefix: String = "", new_stream_url: String = "") -> void:
	if not base_url.is_empty():
		api_base_url = _sanitize_base_url(base_url)
	if not path_prefix.is_empty():
		api_path_prefix = _sanitize_path_prefix(path_prefix)
	if not new_stream_url.is_empty():
		stream_url = new_stream_url.strip_edges()


func set_stream_url(url: String) -> void:
	stream_url = url.strip_edges()


func set_access_token(token: String) -> void:
	auth_token = token.strip_edges()


func clear_access_token() -> void:
	auth_token = ""


func configure_from_settings() -> void:
	var env_url := OS.get_environment("FOURALL_API_BASE_URL")
	if not env_url.is_empty():
		api_base_url = _sanitize_base_url(env_url)
	else:
		const PROJECT_SETTING_BASE := "application/config/4all_api_base_url"
		if ProjectSettings.has_setting(PROJECT_SETTING_BASE):
			var configured = ProjectSettings.get_setting(PROJECT_SETTING_BASE)
			if typeof(configured) == TYPE_STRING and not String(configured).is_empty():
				api_base_url = _sanitize_base_url(String(configured))

	const PROJECT_SETTING_PATH := "application/config/4all_api_path"
	if ProjectSettings.has_setting(PROJECT_SETTING_PATH):
		var configured_path = ProjectSettings.get_setting(PROJECT_SETTING_PATH)
		if typeof(configured_path) == TYPE_STRING and not String(configured_path).is_empty():
			api_path_prefix = _sanitize_path_prefix(String(configured_path))

	const PROJECT_SETTING_STREAM := "application/config/4all_stream_url"
	if ProjectSettings.has_setting(PROJECT_SETTING_STREAM):
		var configured_stream = ProjectSettings.get_setting(PROJECT_SETTING_STREAM)
		if typeof(configured_stream) == TYPE_STRING:
			stream_url = String(configured_stream).strip_edges()


func login(email: String, password: String) -> Dictionary:
	var response := await _send_api_request(HTTPClient.METHOD_POST, "auth/login", {
		"email": email,
		"password": password
	})

	if response.get("ok", false) and response.has("data"):
		response["payload"] = extract_payload(response["data"])

	return response


func request_otp(email: String, password: String) -> Dictionary:
	var response := await _send_api_request(HTTPClient.METHOD_POST, "auth/request-otp", {
		"email": email,
		"password": password
	})

	if response.get("ok", false) and response.has("data"):
		response["payload"] = extract_payload(response["data"])

	return response


func verify_otp(email: String, otp: String) -> Dictionary:
	var response := await _send_api_request(HTTPClient.METHOD_POST, "auth/verify-otp", {
		"email": email,
		"otp": otp
	})

	if response.get("ok", false) and response.has("data"):
		response["payload"] = extract_payload(response["data"])

	return response


func update_bridge_token(token: String) -> Dictionary:
	var trimmed := token.strip_edges()
	if trimmed.is_empty():
		return {"ok": false, "error": "Token cannot be empty."}

	return await _send_api_request(HTTPClient.METHOD_POST, "config/user-token", {
		"token": trimmed
	})


func init_arena_game(custom_stream_url: String = "") -> Dictionary:
	var payload: Dictionary = {}
	var resolved_stream := custom_stream_url.strip_edges()
	if resolved_stream.is_empty():
		resolved_stream = stream_url
	if not resolved_stream.is_empty():
		payload["streamUrl"] = resolved_stream

	return await _send_api_request(HTTPClient.METHOD_POST, "games", payload)


func sync_session(access_token: String, custom_stream_url: String = "") -> Dictionary:
	var trimmed := access_token.strip_edges()
	if trimmed.is_empty():
		return {"ok": false, "error": "Access token cannot be empty."}

	set_access_token(trimmed)

	var update_response := await update_bridge_token(trimmed)
	if not update_response.get("ok", false):
		return update_response

	return await init_arena_game(custom_stream_url)


func fetch_profile() -> Dictionary:
	var response := await _send_api_request(HTTPClient.METHOD_GET, "profile")
	if response.get("ok", false) and response.has("data"):
		response["payload"] = extract_payload(response["data"])
	return response


func update_player_stats(stats: Dictionary) -> Dictionary:
	if auth_token.is_empty():
		return {"ok": false, "error": "Access token required for stats update."}

	return await _send_api_request(HTTPClient.METHOD_POST, "games/stats", stats)


func submit_run_summary(summary: Dictionary) -> Dictionary:
	if auth_token.is_empty():
		return {"ok": false, "error": "Access token required for run summary."}

	return await _send_api_request(HTTPClient.METHOD_POST, "games/runs", summary)


func acknowledge_event(event_type: String, payload: Dictionary = {}) -> Dictionary:
	if auth_token.is_empty():
		return {"ok": false, "error": "Access token required for event acknowledgement."}

	var safe_payload: Dictionary = payload.duplicate(true)
	var body: Dictionary = {
		"eventType": event_type,
		"payload": safe_payload,
		"clientTimestamp": Time.get_unix_time_from_system()
	}

	return await _send_api_request(HTTPClient.METHOD_POST, "events/ack", body)


func extract_payload(response_data: Dictionary) -> Dictionary:
	var current := response_data
	var depth := 0
	while typeof(current) == TYPE_DICTIONARY and current.has("data") and depth < 4:
		var next_layer = current.get("data")
		if typeof(next_layer) == TYPE_DICTIONARY:
			current = next_layer
			depth += 1
		else:
			break
	return current


func get_error_message(response: Dictionary, default_message: String) -> String:
	if response.has("error"):
		return str(response["error"])

	if response.has("data") and typeof(response["data"]) == TYPE_DICTIONARY:
		var data: Dictionary = response["data"]
		if data.has("error"):
			return str(data["error"])
		if data.has("message"):
			return str(data["message"])

		var payload := extract_payload(data)
		if payload.has("error"):
			return str(payload["error"])
		if payload.has("message"):
			return str(payload["message"])

	if response.has("raw_body") and str(response["raw_body"]).length() > 0:
		return str(response["raw_body"])

	if response.has("status_code"):
		return "%s (HTTP %d)" % [default_message, int(response["status_code"])]

	return default_message


func _send_api_request(method: int, path: String, payload: Dictionary = {}, extra_headers: Array = []) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = API_TIMEOUT_SECONDS
	add_child(request)

	var body := ""
	if not payload.is_empty():
		body = JSON.stringify(payload)

	var err := request.request(_build_api_url(path), _create_request_headers(extra_headers), method, body)
	if err != OK:
		request.queue_free()
		return {
			"ok": false,
			"error": "Failed to start request",
			"code": err
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result: int = result[0]
	var status_code: int = result[1]
	var body_bytes: PackedByteArray = result[3]

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"error": "Network error",
			"result": request_result,
			"status_code": status_code
		}

	var body_text := ""
	if body_bytes:
		body_text = body_bytes.get_string_from_utf8()

	var json := JSON.new()
	var parse_err := json.parse(body_text)
	var data := {}
	if parse_err == OK and typeof(json.data) == TYPE_DICTIONARY:
		data = json.data

	var success: bool = (
		status_code >= 200
		and status_code < 300
		and typeof(data) == TYPE_DICTIONARY
		and bool(data.get("success", false))
	)

	return {
		"ok": success,
		"status_code": status_code,
		"data": data,
		"raw_body": body_text
	}


func _build_api_url(path: String) -> String:
	if path.begins_with("http://") or path.begins_with("https://"):
		return path

	var relative := _trim_leading_slash(path)
	if api_path_prefix.is_empty():
		return "%s/%s" % [api_base_url, relative]
	else:
		return "%s%s/%s" % [api_base_url, api_path_prefix, relative]


func _create_request_headers(extra_headers: Array = []) -> Array:
	var headers: Array = ["Content-Type: application/json"]
	if not auth_token.is_empty():
		headers.append("Authorization: Bearer %s" % auth_token)
	headers.append_array(extra_headers)
	return headers


func _trim_leading_slash(path: String) -> String:
	if path.begins_with("/"):
		return path.substr(1, path.length() - 1)
	return path


func _sanitize_base_url(url: String) -> String:
	var trimmed := url.strip_edges()
	if trimmed.ends_with("/"):
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	return trimmed


func _sanitize_path_prefix(path: String) -> String:
	var normalized := path.strip_edges()
	if normalized.is_empty():
		return ""
	if not normalized.begins_with("/"):
		normalized = "/" + normalized
	if normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized

