import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:maid/utilities/message_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:maid/utilities/memory_manager.dart';

Character character = Character();

class Character {  
  String name = "Maid";
  
  TextEditingController prePromptController = TextEditingController();
  
  List<TextEditingController> examplePromptControllers = [];
  List<TextEditingController> exampleResponseControllers = [];

  TextEditingController userAliasController = TextEditingController();
  TextEditingController responseAliasController = TextEditingController();

  bool busy = false;

  Character() {
    resetAll();
  }

  Character.fromMap(Map<String, dynamic> inputJson) {
    name = inputJson["name"] ?? "Unknown";

    if (inputJson.isEmpty) {
      resetAll();
    }

    prePromptController.text = inputJson["pre_prompt"] ?? "";
    userAliasController.text = inputJson["user_alias"] ?? "";
    responseAliasController.text = inputJson["response_alias"] ?? "";

    examplePromptControllers.clear();
    exampleResponseControllers.clear();

    if (inputJson["example"] == null) return;

    int length = inputJson["example"].length ?? 0;
    for (var i = 0; i < length; i++) {
      String? examplePrompt = inputJson["example"][i]["prompt"];
      String? exampleResponse = inputJson["example"][i]["response"];
      if (examplePrompt != null && exampleResponse != null) {
        examplePromptControllers.add(TextEditingController(text: examplePrompt));
        exampleResponseControllers.add(TextEditingController(text: exampleResponse));
      }
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> jsonCharacter = {};

    jsonCharacter["name"] = name;
    
    jsonCharacter["pre_prompt"] = prePromptController.text;
    jsonCharacter["user_alias"] = userAliasController.text;
    jsonCharacter["response_alias"] = responseAliasController.text;

    // Initialize the "example" key to an empty list
    jsonCharacter["example"] = [];

    for (var i = 0; i < examplePromptControllers.length; i++) {
      // Create a map for each example and add it to the "example" list
      Map<String, String> example = {
        "prompt": examplePromptControllers[i].text,
        "response": exampleResponseControllers[i].text,
      };

      jsonCharacter["example"].add(example);
    }

    return jsonCharacter;
  }

  void resetAll() async {
    // Reset all the internal state to the defaults
    String jsonString = await rootBundle.loadString('assets/default_character.json');

    Map<String, dynamic> jsonCharacter = json.decode(jsonString);

    prePromptController.text = jsonCharacter["pre_prompt"] ?? "";
    userAliasController.text = jsonCharacter["user_alias"] ?? "";
    responseAliasController.text = jsonCharacter["response_alias"] ?? "";

    examplePromptControllers.clear();
    exampleResponseControllers.clear();

    if (jsonCharacter["example"] != null) {
      int length = jsonCharacter["example"]?.length ?? 0;
      for (var i = 0; i < length; i++) {
        String? examplePrompt = jsonCharacter["example"][i]["prompt"];
        String? exampleResponse = jsonCharacter["example"][i]["response"];
        if (examplePrompt != null && exampleResponse != null) {
          examplePromptControllers.add(TextEditingController(text: examplePrompt));
          exampleResponseControllers.add(TextEditingController(text: exampleResponse));
        }
      }
    }

    memoryManager.save();
  }

  Future<String> saveCharacterToJson(BuildContext context) async {
    Map<String, dynamic> jsonCharacter = {};

    jsonCharacter["name"] = name;
    
    jsonCharacter["pre_prompt"] = prePromptController.text;
    jsonCharacter["user_alias"] = userAliasController.text;
    jsonCharacter["response_alias"] = responseAliasController.text;

    // Initialize the "example" key to an empty list
    jsonCharacter["example"] = [];

    for (var i = 0; i < examplePromptControllers.length; i++) {
      // Create a map for each example and add it to the "example" list
      Map<String, String> example = {
        "prompt": examplePromptControllers[i].text,
        "response": exampleResponseControllers[i].text,
      };

      jsonCharacter["example"].add(example);
    }

    // Convert the map to a JSON string
    String jsonString = json.encode(jsonCharacter);
    String? filePath;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        Directory? directory;
        if (Platform.isAndroid && (await Permission.manageExternalStorage.request().isGranted)) {
          directory = await Directory('/storage/emulated/0/Download/Maid').create();
        } 
        else if (Platform.isIOS && (await Permission.storage.request().isGranted)) {
          directory = await getDownloadsDirectory();
        } else {
          return "Permission Request Failed";
        }

        filePath = '${directory!.path}/maid_character.json';
      }
      else {
        filePath = await FilePicker.platform.saveFile(type: FileType.any);
      }

      if (filePath != null) {
        File file = File(filePath);
        await file.writeAsString(jsonString);
      } else {
        return "No File Selected";
      }
    } catch (e) {
      return "Error: $e";
    }
    return "Character Successfully Saved to $filePath";
  }

  Future<String> loadCharacterFromJson(BuildContext context) async {
    if ((Platform.isAndroid || Platform.isIOS)) {
      if (!(await Permission.storage.request().isGranted) || 
          !(await Permission.manageExternalStorage.request().isGranted)
      ) {
        return "Permission Request Failed";
      }
    }
    
    Directory initialDirectory = await MemoryManager.getInitialDirectory();

    final localContext = context;
    if (!context.mounted) return "Failed to load character";
    
    try{
      var result = await FilesystemPicker.open(
        allowedExtensions: [".json"],
        context: localContext,
        rootDirectory: initialDirectory,
        fileTileSelectMode: FileTileSelectMode.wholeTile,
        fsType: FilesystemType.file
      );

      if (result == null) {
        busy = false;
        return "Failed to load character";
      }

      File file = File(result);
      String jsonString = await file.readAsString();
      if (jsonString.isEmpty) return "Failed to load character";
      
      Map<String, dynamic> jsonCharacter = {};

      jsonCharacter = json.decode(jsonString);
      if (jsonCharacter.isEmpty) {
        resetAll();
        return "Failed to decode character";
      }

      name = jsonCharacter["name"] ?? "";

      prePromptController.text = jsonCharacter["pre_prompt"] ?? "";
      userAliasController.text = jsonCharacter["user_alias"] ?? "";
      responseAliasController.text = jsonCharacter["response_alias"] ?? "";

      int length = jsonCharacter["example"]?.length ?? 0;
      for (var i = 0; i < length; i++) {
        String? examplePrompt = jsonCharacter["example"][i]["prompt"];
        String? exampleResponse = jsonCharacter["example"][i]["response"];
        if (examplePrompt != null && exampleResponse != null) {
          examplePromptControllers.add(TextEditingController(text: examplePrompt));
          exampleResponseControllers.add(TextEditingController(text: exampleResponse));
        }
      }
    } catch (e) {
      resetAll();
      return "Error: $e";
    }

    return "Character Successfully Loaded";
  }
  
  String getPrePrompt() {
    String prePrompt = prePromptController.text.isNotEmpty ? prePromptController.text.trim() : "";
    for (var i = 0; i < examplePromptControllers.length; i++) {
      var prompt = '${userAliasController.text.trim()} ${examplePromptControllers[i].text.trim()}';
      var response = '${responseAliasController.text.trim()} ${exampleResponseControllers[i].text.trim()}';
      if (prompt.isNotEmpty && response.isNotEmpty) {
        prePrompt += "\n$prompt\n$response";
      }
    }

    Map<String, bool> history = MessageManager.getMessages();
    if (history.isNotEmpty) {
      history.forEach((key, value) {
        if (value) {
          prePrompt += "\n${userAliasController.text.trim()} $key";
        } else {
          prePrompt += "\n${responseAliasController.text.trim()} $key";
        }
      });
    }

    return prePrompt;
  }
}