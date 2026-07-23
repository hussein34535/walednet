import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/providers/vpn_provider.dart';
import 'pc_3d_mascot.dart';

class Desktop3dStage extends StatelessWidget {
  const Desktop3dStage({super.key});

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context);
    final status = vpnProvider.vpnStatus;

    return Center(
      child: Pc3dMascot(
        status: status,
      ),
    );
  }
}
