import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img; // Import the image package
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/presentation/screens/test.dart';
import 'package:store_audit/utility/show_alert.dart';

import '../../db/database_manager.dart';
import '../../utility/app_colors.dart';
import '../../utility/show_progress.dart';
import 'fmcg_sd_store_list.dart';

class FmcgSdStoreClose extends StatefulWidget {
  final List<Map<String, dynamic>> storeList;
  final Map<String, dynamic> storeData;
  final String option;
  const FmcgSdStoreClose(
      {super.key,
      required this.storeList,
      required this.storeData,
      required this.option});

  @override
  State<FmcgSdStoreClose> createState() => _FmcgSdStoreCloseState();
}

class _FmcgSdStoreCloseState extends State<FmcgSdStoreClose> {
  final _remarksController = TextEditingController();
  final List<File> _imageFiles = [];
  File? _image;
  final ImagePicker _picker = ImagePicker(); // Replace with your ImgBB API key
  bool _isUploading = false;
  final DatabaseManager dbManager = DatabaseManager();
  late Map<String, dynamic> _storeData;

  @override
  void initState() {
    super.initState();
    _storeData = widget.storeData;
  }

  Future<void> _takeSelfie() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String customPath = appDir.path;
      final Directory customDir = Directory(customPath);
      if (!customDir.existsSync()) {
        customDir.createSync(recursive: true);
      }

      // Resize the image to 600x600 before saving
      final img.Image? originalImage =
          img.decodeImage(await File(photo.path).readAsBytes());
      if (originalImage != null) {
        final img.Image resizedImage =
            img.copyResize(originalImage, width: 500, height: 500);
        final String timestamp =
            DateTime.now().millisecondsSinceEpoch.toString();
        final String newFileName = 'selfie_852456_$timestamp.jpg';

        final String newPath = '$customPath/$newFileName';
        final File resizedFile = File('${photo.path}_resized.jpg')
          ..writeAsBytesSync(img.encodeJpg(resizedImage));
        final File newImage = await resizedFile.copy(newPath);

        final prefs = await SharedPreferences.getInstance();
        List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];
        savedPaths.add(newPath);
        await prefs.setStringList('imagePaths', savedPaths);

        setState(() {
          _image = newImage;
        });
        print('Image saved at: $newPath');
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      // Show the progress dialog
      ShowProgress.showProgressDialog(context);

      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
      );

      if (pickedFile != null) {
        // Get the application's document directory
        final directory = await getApplicationDocumentsDirectory();
        final customPath = directory.path;

        // Decode and resize the image
        final img.Image? originalImage =
            img.decodeImage(await File(pickedFile.path).readAsBytes());
        if (originalImage != null) {
          final img.Image resizedImage =
              img.copyResize(originalImage, width: 500, height: 500);
          final String timestamp =
              DateTime.now().millisecondsSinceEpoch.toString();
          final String newFileName = 'product_852456_$timestamp.jpg';
          final String newPath = '$customPath/$newFileName';

          // Save resized image
          final File resizedFile = File('${pickedFile.path}_resized.jpg')
            ..writeAsBytesSync(img.encodeJpg(resizedImage));
          final File newImage = await resizedFile.copy(newPath);

          // Save the image path in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];
          savedPaths.add(newPath);
          await prefs.setStringList('imagePaths', savedPaths);

          // Add the resized image to the list
          setState(() {
            _imageFiles.add(newImage);
          });
        }
      }
    } catch (e) {
      print('Error taking photo: $e');
      _showSnackbar('Failed to take a photo.');
    } finally {
      // Close the progress dialog
      Navigator.of(context).pop();
    }
  }

  String sortStatus() {
    if (widget.option == 'Initial Audit (IA)') {
      return 'IA';
    } else if (widget.option == 'Re Audit (RA)') {
      return 'RA';
    } else if (widget.option == 'Temporary Closed (TC)') {
      return 'TC';
    } else if (widget.option == 'Permanent Closed (PC)') {
      return 'PC';
    } else {
      return 'CANS';
    }
  }

  Future<void> _saveSkuUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final String? auditorId = prefs.getString('auditorId');
    final String? dbPath = prefs.getString('dbPath');
    List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];

    await dbManager.closeStore(dbPath!, _storeData['code'], 1, 1, widget.option,
        sortStatus(), 'hey', 'hi');

    ShowAlert.showSnackBar(context, 'Store update submitted successfully!');

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => FMCGSDStores(
              dbPath: dbPath ?? "", // Provide a default value if null
              auditorId: auditorId ?? "")),
    );

    // if (_image == null || _remarksController.text.isEmpty) {
    //   _showSnackbar('Please add a selfie and enter remarks before submitting.');
    //   return;
    // }

    // // Logic to save data in the database
    // print('Remarks: ${_remarksController.text}');
    // print('Image Path: ${_image!.path}');

    //print('Previous Page Data: ${widget.item}');
    //_uploadImage();
    // _showSnackbar('SKU update submitted successfully!');
    //Navigator.pop(context); // Navigate back after submission
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        title: const Text('Test Image Upload'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Remarks...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16.0),
                GestureDetector(
                  onTap: _takeSelfie,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: _image == null
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt,
                                    size: 50, color: Colors.grey),
                                Text(
                                    'Please add a selfie near the store location'),
                              ],
                            ),
                          )
                        : Image.file(_image!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16.0),
                const Text('Add Photos:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, // Horizontal gap between images
                  runSpacing: 8, // Vertical gap between rows of images
                  children: _imageFiles
                      .map((file) => Stack(
                            children: [
                              Image.file(file, width: 100, height: 100),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _imageFiles.remove(file);
                                    });
                                  },
                                  child: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ))
                      .toList(),
                ),
                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _saveSkuUpdate,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor:
                        const Color(0xFF314CA3), // White text color
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(50), // Rounded corners
                    ),
                    padding: EdgeInsets.zero, // Remove extra padding
                    minimumSize: const Size(double.infinity,
                        50), // Ensure button takes full width with specific height
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      height: 1.5, // Adjust line height if needed
                    ),
                  ),
                )
              ],
            ),
          ),
          if (_isUploading)
            Center(
              child: Container(
                color: Colors.black54,
                child: const CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
