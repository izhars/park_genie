// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:multicast_dns/multicast_dns.dart';
// import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
//
// class PrinterSearchScreen extends StatefulWidget {
//   @override
//   _PrinterSearchScreenState createState() => _PrinterSearchScreenState();
// }
//
// class _PrinterSearchScreenState extends State<PrinterSearchScreen> {
//   List<String> _printers = [];
//   bool _isSearching = false;
//
//   Future<void> searchPrinters() async {
//     setState(() {
//       _printers.clear();
//       _isSearching = true;
//     });
//
//     final MDnsClient client = MDnsClient();
//     try {
//       await client.start();
//       List<String> foundPrinters = [];
//
//       await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
//           ResourceRecordQuery.serverPointer('_ipp._tcp.local'))) {
//         await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
//             ResourceRecordQuery.service(ptr.domainName))) {
//           await for (final IPAddressResourceRecord ip in client.lookup<IPAddressResourceRecord>(
//               ResourceRecordQuery.addressIPv4(srv.target))) {
//             foundPrinters.add(ip.address.address);
//           }
//         }
//       }
//
//       setState(() {
//         _printers = foundPrinters;
//       });
//     } catch (e) {
//       print('Error searching printers: $e');
//     } finally {
//       client.stop();
//       setState(() {
//         _isSearching = false;
//       });
//     }
//   }
//
//   Future<void> printReceipt(String printerIp) async {
//     final printer = PrinterNetworkManager(printerIp, port: 9100);
//     try {
//       PosPrintResult res = await printer.connect();
//       if (res == PosPrintResult.success) {
//         final profile = await CapabilityProfile.load();
//         final generator = Generator(PaperSize.mm80, profile);
//
//         final ticket = <int>[];
//         ticket.addAll(generator.text(
//           'Hello Printer!',
//           styles: PosStyles(align: PosAlign.center, bold: true),
//         ));
//         ticket.addAll(generator.feed(2));
//         ticket.addAll(generator.cut());
//
//         final printResult = await printer.printTicket(ticket);
//
//         print(printResult.msg);
//       } else {
//         print('Failed to connect: ${res.msg}');
//       }
//     } catch (e) {
//       print('Error printing receipt: $e');
//     } finally {
//       printer.disconnect();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Search Printers')),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: ElevatedButton(
//               onPressed: _isSearching ? null : searchPrinters,
//               child: Text(_isSearching ? 'Searching...' : 'Search Printers'),
//             ),
//           ),
//           Expanded(
//             child: _printers.isEmpty
//                 ? Center(child: Text('No printers found'))
//                 : ListView.builder(
//               itemCount: _printers.length,
//               itemBuilder: (context, index) {
//                 return Card(
//                   margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                   child: ListTile(
//                     title: Text(_printers[index]),
//                     trailing: IconButton(
//                       icon: Icon(Icons.print),
//                       onPressed: () => printReceipt(_printers[index]),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
