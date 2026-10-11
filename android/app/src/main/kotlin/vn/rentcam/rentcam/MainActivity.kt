package vn.rentcam.rentcam

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.Signature

class MainActivity : FlutterActivity() {
    private val CHANNEL = "vn.rentcam.rentcam/crypto"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generateKeyPair" -> {
                    val alias = call.argument<String>("alias")
                    if (alias != null) {
                        try {
                            val publicKey = generateKeyPair(alias)
                            result.success(publicKey)
                        } catch (e: Exception) {
                            result.error("KEY_GEN_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Alias is null", null)
                    }
                }
                "signData" -> {
                    val alias = call.argument<String>("alias")
                    val data = call.argument<String>("data")
                    if (alias != null && data != null) {
                        try {
                            val signature = signData(alias, data)
                            result.success(signature)
                        } catch (e: Exception) {
                            result.error("SIGN_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Alias or data is null", null)
                    }
                }
                "verifySignature" -> {
                    val alias = call.argument<String>("alias")
                    val data = call.argument<String>("data")
                    val signature = call.argument<String>("signature")
                    if (alias != null && data != null && signature != null) {
                        try {
                            val isValid = verifySignature(alias, data, signature)
                            result.success(isValid)
                        } catch (e: Exception) {
                            result.error("VERIFY_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Alias, data, or signature is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun generateKeyPair(alias: String): String {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)

        if (!keyStore.containsAlias(alias)) {
            val keyPairGenerator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore"
            )
            val parameterSpec = KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            )
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)
                .build()
            keyPairGenerator.initialize(parameterSpec)
            keyPairGenerator.generateKeyPair()
        }

        val publicKey = keyStore.getCertificate(alias).publicKey
        return Base64.encodeToString(publicKey.encoded, Base64.NO_WRAP)
    }

    private fun signData(alias: String, data: String): String {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)
        val privateKey = keyStore.getKey(alias, null) as PrivateKey

        val signature = Signature.getInstance("SHA256withRSA")
        signature.initSign(privateKey)
        signature.update(data.toByteArray(Charsets.UTF_8))
        val signatureBytes = signature.sign()
        
        return Base64.encodeToString(signatureBytes, Base64.NO_WRAP)
    }

    private fun verifySignature(alias: String, data: String, signatureStr: String): Boolean {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)
        val publicKey = keyStore.getCertificate(alias)?.publicKey 
            ?: throw Exception("Public key not found for alias: $alias")

        val signature = Signature.getInstance("SHA256withRSA")
        signature.initVerify(publicKey)
        signature.update(data.toByteArray(Charsets.UTF_8))
        
        val signatureBytes = Base64.decode(signatureStr, Base64.NO_WRAP)
        return signature.verify(signatureBytes)
    }
}
