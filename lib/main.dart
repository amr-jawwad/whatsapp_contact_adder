import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:azlistview/azlistview.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(const MyApp());
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class ContactItem extends ISuspensionBean {
  final String tag;
  final Contact contact;

  ContactItem(String name, this.contact)
      : tag = name.isNotEmpty ? name[0].toUpperCase() : "#";

  @override
  String getSuspensionTag() => tag;
}

class _ContactsScreenState extends State<ContactsScreen>
    with WidgetsBindingObserver {
  List<ContactItem> contacts = [];
  List<ContactItem> filteredContacts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Observe lifecycle changes
    _fetchContacts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this); // Stop observing when screen is closed
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchContacts(); // Refresh contacts when app is resumed
    }
  }

  Future<void> _fetchContacts() async {
    if (await FlutterContacts.requestPermission()) {
      List<Contact> fetchedContacts =
          await FlutterContacts.getContacts(withProperties: true);

      List<ContactItem> contactItems = fetchedContacts.map((contact) {
        return ContactItem(contact.displayName, contact);
      }).toList();

      SuspensionUtil.sortListBySuspensionTag(contactItems);
      SuspensionUtil.setShowSuspensionStatus(contactItems);

      setState(() {
        contacts = contactItems;
        filteredContacts = contacts;
      });
    }
  }

  void filter(String searchText) {
    List<ContactItem> results = [];
    if (searchText.isEmpty) {
      results = contacts;
    } else {
      results = contacts.where((contactItem) {
        return contactItem.contact.displayName
            .toLowerCase()
            .contains(searchText.toLowerCase());
      }).toList();
    }

    setState(() {
      filteredContacts = results;
    });
  }

  Future<void> _addNewContact(String phoneNumber) async {
    if (await FlutterContacts.requestPermission()) {
      await FlutterContacts.openExternalInsert(phoneNumber.isNotEmpty
          ? Contact(phones: [Phone(phoneNumber)])
          : null); // ✅ Opens Android native form
      _fetchContacts();
    }
  }

  Future<void> _editContact(Contact contact) async {
    await FlutterContacts.openExternalEdit(contact.id);
    _fetchContacts(); // Refresh contacts when returning
  }

  void _showPhoneNumberInputDialog() {
    TextEditingController phoneController = TextEditingController();
    bool isValid = false;

    void validateInput(String input) {
      final regex =
          RegExp(r'^(?:\+|00)\d{4,18}$'); // Allows numbers and a leading '+'
      isValid = regex.hasMatch(input);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          // To update UI when text changes
          builder: (context, setState) {
            return AlertDialog(
              // title: const Text("Enter Phone Number",),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    cursorColor: Colors.green,
                    decoration: InputDecoration(
                        labelText: "Enter Phone Number",
                        labelStyle: TextStyle(
                          color: Colors.green,
                        ),
                        hintText: "Example: +1234567890",
                        border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green)),
                        focusedBorder: const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.green, width: 2.0)),
                        enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green)),
                        // Green border),
                        errorText: isValid || phoneController.text.isEmpty
                            ? null
                            : "Invalid phone number,\nor missing country code (+)",
                        suffixIcon: IconButton(
                            onPressed: () => {
                                  _addNewContact(isValid
                                      ? phoneController.text.trim()
                                      : "")
                                },
                            icon: Icon(
                              Icons.person_add_alt_1,
                              color: Colors.green,
                            ))),
                    onChanged: (value) {
                      setState(() {
                        validateInput(value);
                      });
                    },
                  )
                ],
              ),
              actions: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context), // Close dialog
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),

                      child:
                          const Text("Cancel", style: TextStyle(fontSize: 15)),
                    ),
                    Spacer(),
                    Spacer(),
                    TextButton(
                      onPressed: isValid
                          ? () {
                              Navigator.pop(context);
                              _openContactURL(phoneController.text.trim());
                            }
                          : null,
                      // Disable button if input is invalid
                      style: TextButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor:
                              MediaQuery.of(context).platformBrightness ==
                                      Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                          disabledBackgroundColor: Colors.grey.withAlpha(0),
                          disabledForegroundColor:
                              Theme.of(context).disabledColor),
                      child: const Text("Instant Text!",
                          style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openContactURL(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      return;
    }
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url =
        Uri.parse('https://api.whatsapp.com/send/?phone=$phoneNumber');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print("❌ Could not launch $url");
    }
  }

  void _handleContactTap(Contact contact) {
    if (contact.phones.length > 1) {
      _showPhoneNumberDialog(contact);
    } else if (contact.phones.isNotEmpty) {
      _openContactURL(contact.phones[0].number);
    } else {
      Fluttertoast.showToast(
        msg: "Contact has no valid phone numbers",
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  void _showPhoneNumberDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Select Phone Number"),
          content: SingleChildScrollView(
            child: Column(
              children: contact.phones.map((phone) {
                String label = phone.label.toString().split('.').last;
                label = label[0].toUpperCase() + label.substring(1);
                return ListTile(
                  title: Text("$label: ${phone.number}"),
                  onTap: () {
                    Navigator.pop(context);
                    _openContactURL(phone.number);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "WhatsApp Contacts Adder",
        ),
      ),
      body: Column(children: [
        TextFormField(
          cursorColor: Colors.green,
          onChanged: (value) {
            filter(value);
          },
          decoration: InputDecoration(
            labelText: "Search",
            labelStyle: TextStyle(
              color: Colors.green,
            ),
            hintText: "Search..",
            contentPadding: EdgeInsets.fromLTRB(20.0, 0, 0, 0),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
              // Change underline color
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: Colors.green,
                  width: 2.0), // Change focused underline color
            ),
          ),
        ),
        Expanded(
            child: AzListView(
          data: filteredContacts,
          itemCount: filteredContacts.length,
          indexBarOptions: IndexBarOptions(
            needRebuild: true,
            indexHintAlignment: Alignment.centerRight,
            indexHintOffset: const Offset(-20, 0),
            textStyle: const TextStyle(fontSize: 12),
            indexHintTextStyle: const TextStyle(fontSize: 24),
            indexHintDecoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          itemBuilder: (context, index) {
            final contact = filteredContacts[index].contact;
            return Column(
              children: [
                if (filteredContacts[index].isShowSuspension)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    // color: Colors.green,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      filteredContacts[index].tag,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ListTile(
                  leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      foregroundColor:
                          MediaQuery.of(context).platformBrightness ==
                                  Brightness.dark
                              ? Colors.black
                              : Colors.white,
                      child: Text(contact.displayName[0])),
                  title: Text(contact.displayName),
                  onTap: () => _handleContactTap(contact),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: Colors.green,
                    ),
                    onPressed: () => _editContact(contact),
                  ),
                ),
              ],
            );
          },
        ))
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPhoneNumberInputDialog, // Directly call _addNewContact
        child: Icon(Icons.add, size: 36),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Contact Adder',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.green,
        // Sets the overall theme color
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.green, // Floating button color
          foregroundColor: Colors.white, // Icon color
        ),
        primaryColorLight: Colors.green,
        primaryColor: Colors.green,
        dividerColor: Colors.green,
      ),
      darkTheme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.green,
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.green, // Ensure it's blue in dark mode too
            foregroundColor: Colors.black,
          ),
          primaryColorLight: Colors.green,
          primaryColor: Colors.green,
          dividerColor: Colors.green),
      // Dark theme
      home: const ContactsScreen(),
      // Now this works
      color: Colors.green,
    );
  }
}
