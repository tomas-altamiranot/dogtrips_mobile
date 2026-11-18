package com.dogtrips.dogtrips_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity y no FlutterActivity: el dialogo de huella de
// Android (BiometricPrompt) solo funciona dentro de una FragmentActivity.
// Con la clase de antes, local_auth falla al intentar mostrarlo.
class MainActivity : FlutterFragmentActivity()
