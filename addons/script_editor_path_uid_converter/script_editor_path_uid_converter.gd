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

func initialized() -> void:
	var script_editor:ScriptEditor = EditorInterface.get_script_editor()
	if not script_editor.is_node_ready():
		await script_editor.ready
	
	script_editor.editor_script_changed.connect(update_code_edits.bind(script_editor).unbind(1))
	update_code_edits(script_editor)

const EditorHelpBitToolTipHelper = preload("uid://c4oaf7y81tido")
const _CONVERT_TO_PATH_OR_UID_META_CLICK_TEXT:String = "convert_to_path_or_uid"

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
	
	tooltip_helper.text_label.newline()
	tooltip_helper.text_label.push_meta(_CONVERT_TO_PATH_OR_UID_META_CLICK_TEXT, RichTextLabel.META_UNDERLINE_ON_HOVER)
	
	
	var icon_name:StringName = &"UID" if symbol.begins_with("res") else &"NodePath"
	var icon:Texture2D = EditorInterface.get_base_control().get_theme_icon(icon_name, &"EditorIcons")
	tooltip_helper.text_label.add_image(icon)
	tooltip_helper.text_label.add_text("  ")
	
	var text:String = ""
	
	var locale:String = TranslationServer.get_locale()
	match locale:
		"ja":
			text = "UIDに変換" if symbol.begins_with("res") else "Pathに変換"
		_:
			text = "convert to UID" if symbol.begins_with("res") else "convert to Path"
	
	
	tooltip_helper.text_label.add_text(text)
	
	
	tooltip_helper.text_label.pop()
	tooltip_helper.text_label.meta_clicked.connect(_on_meta_clicked.bind(symbol, line, column, code_edit, tooltip_helper))
	
	if not tooltip_helper.text_label.is_finished():
		await tooltip_helper.text_label.finished
	
	tooltip_helper.tooltip.size.y += tooltip_helper.text_label.get_line_height(0)


func _on_meta_clicked(meta:Variant, symbol: String, line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper) -> void:
	if meta == _CONVERT_TO_PATH_OR_UID_META_CLICK_TEXT:
		_convert(symbol, line, column, code_edit, tooltip_helper)

func _convert(symbol: String, line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper) -> void:
	
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
