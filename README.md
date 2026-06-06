# Roblox Map Development Thesis

Repository ini berisi source code dan dokumentasi teknis untuk pengembangan map interaktif berbasis Roblox yang digunakan dalam proyek skripsi.

Proyek ini dikembangkan menggunakan **Roblox Studio** dan bahasa pemrograman **Lua**. Repository ini berfungsi sebagai tempat penyimpanan kode, dokumentasi pengembangan, serta arsip teknis selama proses perancangan, implementasi, pengujian, dan evaluasi sistem.

## Informasi Proyek

| Keterangan | Detail |
|---|---|
| Nama Repository | `roblox-map-development-thesis` |
| Platform | Roblox |
| Game Engine | Roblox Studio |
| Bahasa Pemrograman | Lua |
| Jenis Proyek | Pengembangan Map Roblox untuk Skripsi |
| Status | Dalam Pengembangan |
| Tujuan | Dokumentasi dan implementasi sistem map Roblox |

## Deskripsi Proyek

Proyek ini merupakan bagian dari penelitian skripsi yang berfokus pada pengembangan map interaktif di platform Roblox. Map yang dikembangkan dirancang untuk mendukung pengalaman pengguna melalui fitur-fitur interaktif, mekanik permainan, sistem navigasi, dan elemen pendukung lainnya.

Seluruh script dalam repository ini disusun berdasarkan lokasi dan fungsi penggunaannya di Roblox Studio, sehingga proses pengembangan menjadi lebih terstruktur, mudah dipelihara, dan dapat didokumentasikan dengan baik untuk kebutuhan akademik.

## Tujuan Pengembangan

Tujuan utama dari proyek ini adalah:

- Mengembangkan map interaktif berbasis Roblox.
- Mengimplementasikan script Lua untuk mendukung fitur dalam map.
- Memisahkan logika client, server, shared module, dan workspace agar struktur kode lebih rapi.
- Mendokumentasikan proses pengembangan sistem untuk kebutuhan skripsi.
- Menyediakan arsip source code yang dapat digunakan untuk pengujian dan evaluasi.

## Teknologi yang Digunakan

- **Roblox Studio** sebagai platform pengembangan.
- **Lua** sebagai bahasa pemrograman utama.
- **Git** sebagai version control system.
- **GitHub** sebagai repository penyimpanan source code.
- **Roblox Engine** sebagai runtime environment.

## Struktur Repository

```text
roblox-map-development-thesis/
├── client/
├── full code/
├── server/
├── shared/
├── workspace/
└── README.md
```

## Penjelasan Struktur Folder

### `client/`

Folder ini berisi script yang berjalan di sisi client atau perangkat pemain. Script pada folder ini biasanya digunakan untuk mengatur interaksi lokal, antarmuka pengguna, efek visual, input pemain, dan fitur yang hanya dijalankan pada sisi pemain.

Contoh isi folder:

- LocalScript
- UI Controller
- Player Input Handler
- Camera Controller
- Visual Effect Handler

### `server/`

Folder ini berisi script yang berjalan di sisi server. Script server digunakan untuk mengatur logika utama sistem, validasi interaksi, pengelolaan data, serta fitur gameplay yang harus dikontrol secara terpusat.

Contoh isi folder:

- ServerScript
- Game Manager
- Checkpoint System
- Teleport System
- Spawn System
- Player Handler

### `shared/`

Folder ini berisi script atau module yang dapat digunakan bersama oleh client dan server. Folder ini biasanya digunakan untuk menyimpan konfigurasi, fungsi bantuan, data umum, dan ModuleScript yang dipakai oleh beberapa bagian sistem.

Contoh isi folder:

- ModuleScript
- Configuration Module
- Utility Function
- Shared Data
- RemoteEvent Reference
- RemoteFunction Reference

### `workspace/`

Folder ini berisi script atau struktur yang berkaitan langsung dengan objek di dalam Workspace Roblox Studio. Folder ini digunakan untuk menyimpan kode yang terhubung dengan objek map, area interaktif, trigger, checkpoint, dan komponen environment.

Contoh isi folder:

- Script pada objek map
- Trigger area
- Checkpoint object
- Teleport object
- Interactive part
- Map component

### `full code/`

Folder ini berisi kumpulan kode lengkap dari proyek. Folder ini dapat digunakan sebagai arsip utama, backup kode, atau dokumentasi source code keseluruhan yang digunakan dalam pengembangan map Roblox.

## Fitur yang Dikembangkan

Beberapa fitur yang dikembangkan atau dapat dikembangkan dalam proyek ini meliputi:

- Sistem map interaktif
- Sistem navigasi pemain
- Sistem checkpoint
- Sistem teleportasi
- Sistem spawn pemain
- Sistem interaksi objek
- Sistem trigger area
- Sistem UI pemain
- Script client dan server
- ModuleScript untuk fungsi pendukung
- Integrasi objek map dengan script Lua

## Alur Pengembangan Sistem

Tahapan pengembangan proyek dilakukan melalui beberapa proses berikut:

1. Analisis kebutuhan sistem map Roblox.
2. Perancangan konsep dan struktur map.
3. Pembuatan objek dan environment menggunakan Roblox Studio.
4. Implementasi script menggunakan bahasa Lua.
5. Pemisahan script berdasarkan client, server, shared, dan workspace.
6. Pengujian fitur menggunakan mode Play/Test di Roblox Studio.
7. Perbaikan bug dan optimasi script.
8. Dokumentasi kode dan hasil pengembangan untuk kebutuhan skripsi.
9. Penyimpanan source code ke GitHub.

## Cara Menggunakan Repository

1. Clone repository ini ke perangkat lokal:

```bash
git clone https://github.com/luciaans/roblox-map-development-thesis.git
```

2. Buka aplikasi **Roblox Studio**.

3. Buka project Roblox yang digunakan untuk pengembangan map.

4. Masukkan script ke lokasi yang sesuai di Roblox Studio:

```text
client/    -> StarterPlayerScripts atau StarterGui
server/    -> ServerScriptService
shared/    -> ReplicatedStorage
workspace/ -> Workspace
```

5. Jalankan project menggunakan fitur **Play** atau **Test** di Roblox Studio.

6. Lakukan pengujian pada fitur map yang telah dibuat.

## Pengujian

Pengujian dilakukan untuk memastikan setiap fitur berjalan sesuai kebutuhan sistem. Beberapa aspek yang diuji antara lain:

- Fungsi script client dan server.
- Interaksi pemain dengan objek map.
- Sistem checkpoint dan teleportasi.
- Trigger area pada map.
- Respons UI terhadap aksi pemain.
- Stabilitas script saat game dijalankan.
- Kesesuaian fitur dengan rancangan skripsi.

## Dokumentasi Skripsi

Repository ini digunakan sebagai bagian dari dokumentasi teknis dalam pengerjaan skripsi. Source code yang tersedia di dalam repository ini dapat digunakan sebagai bukti implementasi sistem dan pendukung dalam proses penulisan laporan skripsi.

Bagian yang dapat dikaitkan dengan laporan skripsi:

- Perancangan sistem
- Implementasi sistem
- Struktur kode program
- Pengujian fitur
- Evaluasi hasil pengembangan
- Dokumentasi teknis proyek

## Standar Penulisan Kode

Untuk menjaga kualitas kode, beberapa standar yang digunakan dalam proyek ini adalah:

- Nama file disesuaikan dengan fungsi script.
- Script client dan server dipisahkan berdasarkan peran masing-masing.
- ModuleScript digunakan untuk kode yang dapat digunakan ulang.
- Komentar ditambahkan pada bagian kode yang penting.
- Setiap perubahan signifikan disimpan menggunakan Git commit.
- Struktur folder dibuat konsisten agar mudah dipahami.

## Contoh Penamaan Script

```text
GameManager.lua
CheckpointSystem.lua
TeleportSystem.lua
SpawnHandler.lua
PlayerHandler.lua
MapInteractionHandler.lua
UIController.lua
CameraController.lua
SharedConfig.lua
UtilityModule.lua
```

## Status Proyek

```text
Proyek masih dalam tahap pengembangan, pengujian, dan dokumentasi untuk kebutuhan skripsi.
```

## Manfaat Proyek

Proyek ini diharapkan dapat memberikan manfaat sebagai berikut:

- Membantu proses pengembangan map Roblox secara lebih terstruktur.
- Menjadi dokumentasi teknis dalam penyusunan skripsi.
- Mempermudah proses pengujian dan evaluasi fitur.
- Menjadi arsip source code yang dapat ditinjau kembali.
- Menjadi referensi pengembangan map atau game interaktif berbasis Roblox.

## Kontribusi

Repository ini dibuat untuk kebutuhan pribadi dan akademik dalam pengerjaan skripsi. Kontribusi dari pihak lain belum dibuka secara publik, kecuali untuk kebutuhan bimbingan, evaluasi, atau pengujian.

## Lisensi

Repository ini digunakan untuk keperluan akademik. Penggunaan ulang kode dari repository ini harus mencantumkan sumber atau mendapatkan izin dari pemilik repository.

## Penulis

**Lucians**  
Repository: `roblox-map-development-thesis`  
Platform: Roblox Studio  
Bahasa Pemrograman: Lua  
Tahun: 2026
