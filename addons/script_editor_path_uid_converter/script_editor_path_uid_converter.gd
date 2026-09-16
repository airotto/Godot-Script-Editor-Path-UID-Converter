@tool
extends EditorPlugin

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass
	initialized()



func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass


#####################################
#####################################


func _get_action_text_for_convert_to_path() -> String:
	match TranslationServer.get_tool_locale():
		"ja":
			return "Pathに変換"
		_:
			return "convert to Path"

func _get_action_text_for_convert_to_uid() -> String:
	match TranslationServer.get_tool_locale():
		"ja":
			return "UIDに変換"
		_:
			return "convert to UID"


#####################################
#####################################


func initialized() -> void:
	var script_editor:ScriptEditor = EditorInterface.get_script_editor()
	if not script_editor.is_node_ready():
		await script_editor.ready
	
	script_editor.editor_script_changed.connect(update_code_edits.bind(script_editor).unbind(1))
	update_code_edits(script_editor)

const EditorHelpBitToolTipHelper = preload("uid://c4oaf7y81tido")
const _ACTION_CONVERT_TO_PATH_OR_UID_META_CLICK_TEXT:String = "convert_to_path_or_uid"

##ツールチップに　tween　の奴を追加するのがこの関数です
func _on_symbol_hovered(symbol: String, line: int, column: int, code_edit:CodeEdit) -> void:
	if code_edit == null:return
	
	##表示時のみノードが生成されるのでホバーごとにトリガー
	##ツールチップを取得
	var tooltip_node:PopupPanel = code_edit.find_child("*EditorHelpBitTooltip*", false, false)
	if tooltip_node == null:return
	
	
	var tooltip_helper:EditorHelpBitToolTipHelper = EditorHelpBitToolTipHelper.new(tooltip_node)
	
	if tooltip_helper.tooltip.has_meta(&"_triggered___plugin_script_editor_path_uid_converter"):return
	tooltip_helper.tooltip.set_meta(&"_triggered___plugin_script_editor_path_uid_converter", true)
	
	if not ResourceLoader.exists(symbol):return
	
	_trigger(symbol, line, column, code_edit, tooltip_helper)


func _trigger(symbol: String, line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper) -> void:
	var action_quantity:int = 0
	
	var icon_name:StringName = &"UID" if symbol.begins_with("res") else &"NodePath"
	
	_add_action(
		_ACTION_CONVERT_TO_PATH_OR_UID_META_CLICK_TEXT,
		EditorInterface.get_base_control().get_theme_icon(icon_name, &"EditorIcons"),
		_get_action_text_for_convert_to_uid() if symbol.begins_with("res") else _get_action_text_for_convert_to_path(),
		tooltip_helper
	)
	action_quantity += 1
	
	
	tooltip_helper.text_label.meta_clicked.connect(_on_meta_clicked.bind(symbol, line, column, code_edit, tooltip_helper))
	
	if not tooltip_helper.text_label.is_finished():
		await tooltip_helper.text_label.finished
	
	for i in range(action_quantity, 0, -1):
		tooltip_helper.tooltip.size.y += tooltip_helper.text_label.get_line_height(tooltip_helper.text_label.get_line_count() - i)
	
	tooltip_helper.tooltip.size.y += tooltip_helper.text_label.get_line_height(tooltip_helper.text_label.get_line_count() - 1)


func _on_meta_clicked(meta:Variant, symbol: String, line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper) -> void:
	if meta == _ACTION_CONVERT_TO_PATH_OR_UID_META_CLICK_TEXT:
		_action_convert(symbol, line, column, code_edit, tooltip_helper)



func _add_action(meta:Variant, icon:Texture2D, text:String, tooltip_helper:EditorHelpBitToolTipHelper) -> void:
	tooltip_helper.text_label.newline()
	tooltip_helper.text_label.push_meta(meta, RichTextLabel.META_UNDERLINE_ON_HOVER)
	
	tooltip_helper.text_label.add_image(icon)
	tooltip_helper.text_label.add_text("  ")
	
	tooltip_helper.text_label.add_text(text)
	
	
	tooltip_helper.text_label.pop()



func _action_convert(symbol: String, line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper) -> void:
	
	if ResourceLoader.exists(symbol):
		code_edit.begin_complex_operation()
		
		var converted:String = ResourceUID.path_to_uid(symbol) if symbol.begins_with("res") else ResourceUID.uid_to_path(symbol)
		
		var delimiter_start_pos:Vector2i = code_edit.get_delimiter_start_position(line, column)
		code_edit.remove_text(delimiter_start_pos.y, delimiter_start_pos.x, delimiter_start_pos.y, delimiter_start_pos.x + symbol.length())
		code_edit.insert_text(converted, delimiter_start_pos.y, delimiter_start_pos.x)
		
		code_edit.end_complex_operation()
		
		tooltip_helper.tooltip.hide()


func update_code_edits(script_editor:ScriptEditor) -> void:
	if script_editor.get_current_editor() == null:
		return
	var control:Control = script_editor.get_current_editor().get_base_editor()
	if control is not CodeEdit:return
	var code_edit:CodeEdit = control
	
	if not code_edit.symbol_hovered.is_connected(_on_symbol_hovered):
		code_edit.symbol_hovered.connect(_on_symbol_hovered.bind(code_edit))
