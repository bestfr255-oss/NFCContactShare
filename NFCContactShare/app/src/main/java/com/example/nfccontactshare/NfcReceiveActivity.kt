package com.example.nfccontactshare

import android.content.ContentProviderOperation
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.NdefMessage
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import android.provider.ContactsContract

class NfcReceiveActivity : AppCompatActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (NfcAdapter.ACTION_NDEF_DISCOVERED == intent.action) {
            val rawMessages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
            val message = rawMessages?.get(0) as NdefMessage
            val payload = message.records[0].payload
            val contactData = String(payload, Charsets.UTF_8)
            saveContacts(contactData)
        }
    }

    private fun saveContacts(data: String) {
        val entries = data.split("BEGIN:VCARD").filter { it.contains("FN:") }
        for (entry in entries) {
            val name = Regex("FN:(.*)").find(entry)?.groupValues?.get(1) ?: continue
            val phone = Regex("TEL:(.*)").find(entry)?.groupValues?.get(1) ?: continue

            val ops = ArrayList<ContentProviderOperation>()
            ops.add(ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
                .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null)
                .build())
            ops.add(ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
                .withValue(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, name)
                .build())
            ops.add(ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, phone)
                .withValue(ContactsContract.CommonDataKinds.Phone.TYPE, ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE)
                .build())

            contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
        }
    }
}
