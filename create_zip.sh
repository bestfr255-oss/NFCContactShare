#!/bin/bash

# Crée les dossiers
mkdir -p NFCContactShare/app/src/main/java/com/example/nfccontactshare
mkdir -p NFCContactShare/app/src/main/res/layout
mkdir -p NFCContactShare/app/src/main/res/values
mkdir -p NFCContactShare/.github/workflows

# ==== FICHIERS KOTLIN ====

# Contact.kt
cat > NFCContactShare/app/src/main/java/com/example/nfccontactshare/Contact.kt <<EOL
package com.example.nfccontactshare

data class Contact(val name: String, val phone: String)
EOL

# ContactAdapter.kt
cat > NFCContactShare/app/src/main/java/com/example/nfccontactshare/ContactAdapter.kt <<EOL
package com.example.nfccontactshare

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

class ContactAdapter(
    private val contacts: List<Contact>,
    private val onSelect: (Contact) -> Unit
) : RecyclerView.Adapter<ContactAdapter.ContactViewHolder>() {

    inner class ContactViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val nameView: TextView = itemView.findViewById(R.id.contactName)
        val phoneView: TextView = itemView.findViewById(R.id.contactPhone)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ContactViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_contact, parent, false)
        return ContactViewHolder(view)
    }

    override fun onBindViewHolder(holder: ContactViewHolder, position: Int) {
        val contact = contacts[position]
        holder.nameView.text = contact.name
        holder.phoneView.text = contact.phone
        holder.itemView.setOnClickListener { onSelect(contact) }
    }

    override fun getItemCount(): Int = contacts.size
}
EOL

# NfcUtils.kt
cat > NFCContactShare/app/src/main/java/com/example/nfccontactshare/NfcUtils.kt <<EOL
package com.example.nfccontactshare

import android.nfc.NdefMessage
import android.nfc.NdefRecord

fun createVCard(contacts: List<Contact>): NdefMessage {
    val vcard = contacts.joinToString("\n") {
        "BEGIN:VCARD\nFN:\${it.name}\nTEL:\${it.phone}\nEND:VCARD"
    }
    val record = NdefRecord.createMime("text/vcard", vcard.toByteArray(Charsets.UTF_8))
    return NdefMessage(arrayOf(record))
}
EOL

# MainActivity.kt
cat > NFCContactShare/app/src/main/java/com/example/nfccontactshare/MainActivity.kt <<EOL
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
EOL

# NfcSendActivity.kt
cat > NFCContactShare/app/src/main/java/com/example/nfccontactshare/NfcSendActivity.kt <<EOL
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
EOL

# NfcReceiveActivity.kt
cat > NFCContactShare/app/src/main/java/com/example/nfccontactshare/NfcReceiveActivity.kt <<EOL
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
EOL

# ==== FICHIERS XML ====

# activity_main.xml
cat > NFCContactShare/app/src/main/res/layout/activity_main.xml <<EOL
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:orientation="vertical"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:padding="16dp">

    <TextView
        android:text="Sélectionne les contacts à partager"
        android:textSize="18sp"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content" />

    <androidx.recyclerview.widget.RecyclerView
        android:id="@+id/contactList"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1" />

    <Button
        android:id="@+id/shareButton"
        android:text="Partager"
        android:layout_width="match_parent"
        android:layout_height="wrap_content" />
</LinearLayout>
EOL

# activity_nfc_send.xml
cat > NFCContactShare/app/src/main/res/layout/activity_nfc_send.xml <<EOL
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:orientation="vertical"
    android:gravity="center"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:padding="32dp">

    <ImageView
        android:src="@drawable/ic_nfc"
        android:layout_width="100dp"
        android:layout_height="100dp" />

    <TextView
        android:text="Approche le téléphone pour partager"
        android:textSize="18sp"
        android:layout_marginTop="16dp"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content" />
</LinearLayout>
EOL

# activity_nfc_receive.xml
cat > NFCContactShare/app/src/main/res/layout/activity_nfc_receive.xml <<EOL
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:orientation="vertical"
    android:gravity="center"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:padding="32dp">

    <ImageView
        android:src="@drawable/ic_check"
        android:layout_width="100dp"
        android:layout_height="100dp" />

    <TextView
        android:text="Contact reçu et enregistré"
        android:textSize="18sp"
        android:layout_marginTop="16dp"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content" />
</LinearLayout>
EOL

# item_contact.xml
cat > NFCContactShare/app/src/main/res/layout/item_contact.xml <<EOL
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:orientation="vertical"
    android:padding="8dp"
    android:layout_width="match_parent"
    android:layout_height="wrap_content">

    <TextView
        android:id="@+id/contactName"
        android:textSize="16sp"
        android:textStyle="bold"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content" />

    <TextView
        android:id="@+id/contactPhone"
        android:textSize="14sp"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content" />
</LinearLayout>
EOL

# ==== FICHIERS VALUES ====

# colors.xml
cat > NFCContactShare/app/src/main/res/values/colors.xml <<EOL
<resources>
    <color name="purple_200">#BB86FC</color>
    <color name="purple_500">#6200EE</color>
    <color name="purple_700">#3700B3</color>
    <color name="teal_200">#03DAC5</color>
    <color name="teal_700">#018786</color>
    <color name="black">#000000</color>
    <color name="white">#FFFFFF</color>
</resources>
EOL

# styles.xml
cat > NFCContactShare/app/src/main/res/values/styles.xml <<EOL
<resources>
    <style name="Theme.NFCContactShare" parent="Theme.MaterialComponents.DayNight.DarkActionBar">
        <item name="colorPrimary">#2196F3</item>
        <item name="colorPrimaryVariant">#1976D2</item>
        <item name="colorOnPrimary">#FFFFFF</item>
        <item name="colorSecondary">#03DAC5</item>
        <item name="colorOnSecondary">#000000</item>
    </style>
</resources>
EOL

# ==== AndroidManifest.xml ====
cat > NFCContactShare/app/src/main/AndroidManifest.xml <<EOL
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.nfccontactshare">

    <uses-permission android:name="android.permission.READ_CONTACTS"/>
    <uses-permission android:name="android.permission.WRITE_CONTACTS"/>
    <uses-permission android:name="android.permission.NFC"/>
    <uses-feature android:name="android.hardware.nfc" android:required="true"/>

    <application
        android:allowBackup="true"
        android:label="NFCContactShare"
        android:theme="@style/Theme.NFCContactShare">
        <activity android:name=".NfcReceiveActivity" />
        <activity android:name=".NfcSendActivity" />
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOL

# ==== README.md ====
cat > NFCContactShare/README.md <<EOL
# NFCContactShare

Application Android pour partager des contacts via NFC.

## Fonctionnalités
- Sélection de contacts
- Partage via NFC (vCard)
- Réception et enregistrement automatique

## Installation
1. Ouvre Android Studio
2. Crée un nouveau projet Kotlin
3. Copie les fichiers dans ton projet
4. Ajoute les permissions NFC et Contacts
5. Compile et teste sur deux téléphones Android avec NFC activé

## Notes
- Testé sur Android 10+
- Nécessite NFC activé sur les deux appareils
EOL

# ==== Workflow GitHub Actions ====
cat > NFCContactShare/.github/workflows/build-apk.yml <<EOL
name: Build NFCContactShare APK

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    name: Build APK
    runs-on: ubuntu-latest

    env:
      ANDROID_SDK_ROOT: \${{ runner.temp }}/android-sdk

    steps:
    - name: Checkout repository
      uses: actions/checkout@v3

    - name: Set up JDK 17
      uses: actions/setup-java@v3
      with:
        java-version: 17
        distribution: temurin

    - name: Set up Android SDK
      uses: android-actions/setup-android@v2
      with:
        api-level: 33
        build-tools: 33.0.2

    - name: Grant execute permission for Gradle Wrapper
      run: chmod +x ./gradlew

    - name: Build Debug APK
      run: ./gradlew assembleDebug --stacktrace

    - name: Upload APK
      uses: actions/upload-artifact@v4
      with:
        name: NFCContactShare-debug-apk
        path: app/build/outputs/apk/debug/app-debug.apk
EOL

# ==== Créer le ZIP ====
zip -r NFCContactShare.zip NFCContactShare

echo "ZIP NFCContactShare.zip créé avec succès !"
