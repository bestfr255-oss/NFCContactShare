package com.example.nfccontactshare

import android.nfc.NfcAdapter
import android.nfc.NdefMessage
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class NfcSendActivity : AppCompatActivity() {
    private lateinit var nfcAdapter: NfcAdapter
    private lateinit var contacts: List<Contact>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_nfc_send)

        contacts = intent.getParcelableArrayListExtra("contacts") ?: emptyList()
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        val message: NdefMessage = createVCard(contacts)
        nfcAdapter.setNdefPushMessage(message, this)
    }
}
