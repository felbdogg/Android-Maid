import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maid/static/file_manager.dart';
import 'package:maid/static/logger.dart';
import 'package:maid/static/memory_manager.dart';

Model model = Model();

class Model {
  String preset = "Default";
  Map<String, dynamic> parameters = {};

  bool local = false;

  Model() {
    resetAll();
  }

  Model.fromMap(Map<String, dynamic> inputJson) {
    if (inputJson.isEmpty) {
      resetAll();
    } else {
      preset = inputJson["preset"] ?? "Default";
      local = inputJson["local"] ?? false;
      parameters = inputJson;
      Logger.log("Model created with name: ${inputJson["name"]}");
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> jsonModel = {};

    jsonModel = parameters;
    jsonModel["preset"] = preset;
    jsonModel["local"] = local;

    return jsonModel;
  }

  void resetAll() async {
    // Reset all the internal state to the defaults
    String jsonString =
        await rootBundle.loadString('assets/default_parameters.json');

    parameters = json.decode(jsonString);
    local = false;

    MemoryManager.saveModels();
  }

  Future<String> exportModelParameters(BuildContext context) async {
    try {
      parameters["preset"] = preset;
      parameters["local"] = local;

      String jsonString = json.encode(parameters);
      
      File? file = await FileManager.save(context, "$preset.json");

      if (file == null) return "Error saving file";

      await file.writeAsString(jsonString);

      return "Model Successfully Saved to ${file.path}";
    } catch (e) {
      return "Error: $e";
    }
  }

  Future<String> importModelParameters(BuildContext context) async {
    try {
      File? file = await FileManager.load(context, "Load Model JSON", [".json"]);

      if (file == null) return "Error loading file";

      Logger.log("Loading parameters from $file");

      String jsonString = await file.readAsString();
      if (jsonString.isEmpty) return "Failed to load parameters";

      parameters = json.decode(jsonString);
      if (parameters.isEmpty) {
        resetAll();
        return "Failed to decode parameters";
      } else {
        local = parameters["local"] ?? false;
        preset = parameters["preset"] ?? "Default";
      }
    } catch (e) {
      resetAll();
      return "Error: $e";
    }

    return "Parameters Successfully Loaded";
  }

  Future<String> loadModelFile(BuildContext context) async {
    try {
      File? file = await FileManager.load(context, "Load Model File", [".gguf"]);

      if (file == null) return "Error loading file";
      
      Logger.log("Loading model from $file");

      parameters["path"] = file.path;
    } catch (e) {
      return "Error: $e";
    }

    return "Model Successfully Loaded";
  }
}
