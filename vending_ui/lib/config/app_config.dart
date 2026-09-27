class AppConfig {
  // เปลี่ยน IP ตามสภาพแวดล้อม:
  // - Android Emulator: 'http://10.0.2.2:8000'
  // - เครื่องจริง/วง LAN เดียวกัน: 'http://192.168.x.x:8000'
  // - Desktop/Web local: 'http://127.0.0.1:8000'
  static const String baseUrl = "http://127.0.0.1:8000";
}