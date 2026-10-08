extends Node

const VERSION := "0.6.4"
const FEED := "https://raw.githubusercontent.com/EJH-BAE/strifes-of-legends/main/update.json"

var label: Label
var http: HTTPRequest
var setup_path := ""

func start(host: Node, status: Label) -> void:
	label = status
	if not _shipped():
		label.text = "버전 %s" % VERSION
		return
	http = HTTPRequest.new()
	host.add_child(http)
	http.request_completed.connect(_on_feed)
	label.text = "업데이트 확인 중"
	if http.request(FEED) != OK:
		label.text = "버전 %s" % VERSION

func _shipped() -> bool:
	var name := OS.get_executable_path().get_file().to_lower()
	return name.begins_with("strifes of legends") or name.begins_with("strife manager")

func _on_feed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		label.text = "버전 %s" % VERSION
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		label.text = "업데이트 정보를 읽지 못했습니다."
		return
	var remote := str(data.get("version", ""))
	if _newer(remote, VERSION) <= 0:
		label.text = "최신 버전 %s" % VERSION
		return
	var url := str(data.get("installer", ""))
	if url == "":
		label.text = "새 버전 %s 설치 파일이 없습니다." % remote
		return
	label.text = "설치 파일 %s 받는 중" % remote
	setup_path = OS.get_executable_path().get_base_dir().path_join("SoLSetup.exe")
	http.request_completed.disconnect(_on_feed)
	http.request_completed.connect(_on_download)
	http.download_file = setup_path
	if http.request(url) != OK:
		label.text = "설치 파일을 받지 못했습니다."

func _on_download(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(setup_path):
		label.text = "설치 파일을 받지 못했습니다."
		return
	label.text = "매니저와 게임을 설치합니다."
	OS.create_process(setup_path, [])
	get_tree().quit()

func _newer(remote: String, local: String) -> int:
	var aa := remote.split(".")
	var bb := local.split(".")
	for i in 3:
		var av := int(aa[i]) if i < aa.size() else 0
		var bv := int(bb[i]) if i < bb.size() else 0
		if av != bv:
			return 1 if av > bv else -1
	return 0
