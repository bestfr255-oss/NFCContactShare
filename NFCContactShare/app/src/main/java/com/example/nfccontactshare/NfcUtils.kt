package com.example.nfccontactshare

import android.nfc.NdefMessage
import android.nfc.NdefRecord

fun createVCard(contacts: List<Contact>): NdefMessage {
    val vcard = contacts.joinToString("\n") {
        "BEGIN:VCARD\nFN:${it.name}\nTEL:${it.phone}\nEND:VCARD"
    }
    val record = NdefRecord.createMime("text/vcard", vcard.toByteArray(Charsets.UTF_8))
    return NdefMessage(arrayOf(record))
}
