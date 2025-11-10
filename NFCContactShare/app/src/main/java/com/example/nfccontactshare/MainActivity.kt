package com.example.nfccontactshare

import android.content.Intent
import android.os.Bundle
import android.provider.ContactsContract
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.RecyclerView

class MainActivity : AppCompatActivity() {
    private lateinit var contactList: RecyclerView
    private val selectedContacts = mutableListOf<Contact>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        contactList = findViewById(R.id.contactList)
        val contacts = loadContacts()
        contactList.adapter = ContactAdapter(contacts) {
            selectedContacts.add(it)
        }

        findViewById<Button>(R.id.shareButton).setOnClickListener {
            val intent = Intent(this, NfcSendActivity::class.java)
            intent.putParcelableArrayListExtra("contacts", ArrayList(selectedContacts))
            startActivity(intent)
        }
    }

    private fun loadContacts(): List<Contact> {
        val contacts = mutableListOf<Contact>()
        val cursor = contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            null, null, null, null
        )
        cursor?.use {
            while (it.moveToNext()) {
                val name = it.getString(it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME))
                val number = it.getString(it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER))
                contacts.add(Contact(name, number))
            }
        }
        return contacts
    }
}
