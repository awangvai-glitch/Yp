package com.example.myapp

import android.util.Log
import java.net.InetAddress
import java.nio.ByteBuffer

// Merepresentasikan header IP v4 yang disederhanakan.
data class IpV4Header(
    val version: Int,
    val ihl: Int, // Internet Header Length
    var protocol: Int,
    var sourceAddress: InetAddress,
    var destinationAddress: InetAddress
)

class PacketProcessor {

    companion object {
        const val IPV4_PROTOCOL = 4
        const val TCP_PROTOCOL = 6
        const val UDP_PROTOCOL = 17
    }

    /**
     * Menganalisis (parse) buffer byte menjadi representasi header IP.
     */
    fun parse(buffer: ByteArray, length: Int): IpV4Header? {
        if (length < 20) return null
        val byteBuffer = ByteBuffer.wrap(buffer, 0, length)
        val versionAndIhl = byteBuffer.get().toInt() and 0xFF
        val version = versionAndIhl shr 4
        if (version != IPV4_PROTOCOL) return null

        val ihl = versionAndIhl and 0x0F
        val headerLength = ihl * 4
        if (length < headerLength) return null
        
        byteBuffer.position(9)
        val protocol = byteBuffer.get().toInt() and 0xFF
        
        byteBuffer.position(12)
        val sourceAddr = ByteArray(4)
        byteBuffer.get(sourceAddr)
        
        val destAddr = ByteArray(4)
        byteBuffer.get(destAddr)

        return try {
            IpV4Header(
                version = version,
                ihl = ihl,
                protocol = protocol,
                sourceAddress = InetAddress.getByAddress(sourceAddr),
                destinationAddress = InetAddress.getByAddress(destAddr)
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Membangun buffer byte dari sebuah header IP dan payload.
     * Sekarang dengan perhitungan checksum yang benar.
     */
    fun build(header: IpV4Header, payload: ByteArray?): ByteArray {
        val payloadSize = payload?.size ?: 0
        val headerLength = header.ihl * 4
        val totalLength = headerLength + payloadSize
        val buffer = ByteBuffer.allocate(totalLength)

        // Baris 1: Version, IHL, ToS, Total Length
        buffer.put(((header.version shl 4) or header.ihl).toByte())
        buffer.put(0.toByte()) // ToS
        buffer.putShort(totalLength.toShort())

        // Baris 2: Identification, Flags, Fragment Offset
        buffer.putShort(0.toShort()) // ID
        buffer.putShort(0.toShort()) // Flags and Fragment Offset

        // Baris 3: TTL, Protocol, Header Checksum (placeholder for now)
        buffer.put(64.toByte()) // TTL
        buffer.put(header.protocol.toByte())
        val checksumOffset = buffer.position()
        buffer.putShort(0.toShort()) // Checksum placeholder

        // Baris 4: Source Address
        buffer.put(header.sourceAddress.address)

        // Baris 5: Destination Address
        buffer.put(header.destinationAddress.address)

        // Hitung checksum SEBELUM menambahkan payload
        val checksum = calculateChecksum(buffer.array(), 0, headerLength)
        buffer.putShort(checksumOffset, checksum)

        if (payload != null) {
            buffer.put(payload)
        }

        return buffer.array()
    }

    /**
     * Menghitung checksum header IP 16-bit.
     * Header harus dilewatkan tanpa payload.
     */
    private fun calculateChecksum(headerBytes: ByteArray, offset: Int, length: Int): Short {
        var sum = 0
        var i = offset
        while (i < length) {
            // Lewati field checksum itu sendiri
            if (i == offset + 10) {
                i += 2
                continue
            }
            // Gabungkan dua byte menjadi satu short (16-bit)
            val word = ((headerBytes[i].toInt() and 0xFF) shl 8) or (headerBytes[i + 1].toInt() and 0xFF)
            sum += word
            i += 2
        }
        // Tambahkan carry (jika ada) ke bagian bawah 16 bit
        while (sum shr 16 > 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        // Lakukan one's complement (balikkan semua bit)
        // [FIX] Menggunakan operasi bitwise langsung untuk menghindari masalah referensi
        return (sum.inv() and 0xFFFF).toShort()
    }
}
