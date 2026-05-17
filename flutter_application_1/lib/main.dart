import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'widgets/whep_video_widget.dart';
import 'services/settings_service.dart';

// ==========================================
// 全域變數 (現在只作為當前選中寵物的暫存區)
// ==========================================
String globalApiBaseUrl = 'http://137.184.181.86:8000/';
double globalFeedThreshold = 20.0;
double globalWaterThreshold = 15.0;
List<String> globalPetList = []; 
String currentSelectedPet = '';  

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 剛開 App 時，我們只需要知道「有哪些寵物」就好
  globalPetList = await SettingsService.loadPetList();
  
  runApp(const IoTApp());
}

class IoTApp extends StatelessWidget {
  const IoTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IoT Pet Cage',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CA1AF),
          surface: const Color(0xFFF5F7FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(),
    );
  }
}

// ==========================================
// 1. 登入頁面 (Login Page)
// ==========================================
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.pets, size: 80, color: Color(0xFF4CA1AF)),
                const SizedBox(height: 20),
                const Text('歡迎回來', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                const Text('登入以查看您的智慧寵物艙', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 40),
                TextField(
                  decoration: InputDecoration(hintText: '電子郵件', prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(hintText: '密碼', prefixIcon: const Icon(Icons.lock_outline), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 30),
                FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF4CA1AF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PetSelectionPage()));
                  },
                  child: const Text('登入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. 寵物選擇頁面 (Pet Selection Page)
// ==========================================
class PetSelectionPage extends StatefulWidget {
  const PetSelectionPage({super.key});

  @override
  State<PetSelectionPage> createState() => _PetSelectionPageState();
}

class _PetSelectionPageState extends State<PetSelectionPage> {
  // 改用 Map 來記錄「每一隻寵物」的連線狀態
  Map<String, bool> _petOnlineStatus = {};
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkDeviceStatus(); 
  }

  Future<void> _checkDeviceStatus() async {
    if (!mounted) return;
    setState(() { _isLoadingStatus = true; });

    // 針對清單中的「每一隻寵物」，分別抓取牠專屬的 API 網址來測試連線
    for (String petName in globalPetList) {
      try {
        final settings = await SettingsService.loadPetSettings(petName);
        final baseUrl = settings['apiUrl'] as String;
        final formattedUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
        final url = Uri.parse('${formattedUrl}sensors');
        
        final response = await http.get(url, headers: {"ngrok-skip-browser-warning": "true"}).timeout(const Duration(seconds: 2)); 
        _petOnlineStatus[petName] = (response.statusCode == 200);
      } catch (e) {
        _petOnlineStatus[petName] = false;
      }
    }

    if (mounted) {
      setState(() { _isLoadingStatus = false; });
    }
  }

  void _deletePet(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('刪除寵物艙'),
          content: Text('確定要移除「${globalPetList[index]}」嗎？這項操作無法復原。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(
              onPressed: () {
                setState(() { globalPetList.removeAt(index); });
                SettingsService.savePetList(globalPetList); 
                Navigator.pop(context);
              },
              child: const Text('確認刪除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('選擇寵物', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('您今天要查看哪位寶貝的狀態？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 20),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: _checkDeviceStatus,
                color: const Color(0xFF4CA1AF),
                child: globalPetList.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 60),
                          Icon(Icons.pets, size: 80, color: Colors.black12),
                          SizedBox(height: 20),
                          Text('目前尚未綁定任何寵物艙', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black54)),
                          SizedBox(height: 8),
                          Text('請點擊下方按鈕新增您的寵物。', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: globalPetList.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final petName = globalPetList[index];
                          final isOnline = _petOnlineStatus[petName] ?? false;
                          
                          String currentStatus = _isLoadingStatus ? '連線偵測中...' : (isOnline ? '設備已上線' : '設備目前離線');
                          Color statusColor = _isLoadingStatus ? Colors.grey : (isOnline ? Colors.green : Colors.redAccent);

                          return _buildPetCard(
                            context,
                            index: index,
                            name: petName,
                            status: currentStatus,
                            statusColor: statusColor, 
                            icon: Icons.pets,
                            color: Colors.orange,
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Color(0xFF4CA1AF)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPetPage())),
              icon: const Icon(Icons.add, color: Color(0xFF4CA1AF)),
              label: const Text('新增寵物艙綁定', style: TextStyle(color: Color(0xFF4CA1AF), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetCard(BuildContext context, {required int index, required String name, required String status, required Color statusColor, required IconData icon, required Color color}) {
    return GestureDetector(
      onTap: () async {
        // ★ 核心魔法：點擊時，立刻去保險箱把「這隻寵物專屬的設定」拿出來，放進全域變數裡！
        currentSelectedPet = name; 
        final settings = await SettingsService.loadPetSettings(name);
        globalApiBaseUrl = settings['apiUrl'];
        globalFeedThreshold = settings['feedThreshold'];
        globalWaterThreshold = settings['waterThreshold'];

        if (!context.mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigation()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(status, style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => _deletePet(index)),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2.5 新增寵物頁面 (Add Pet Page)
// ==========================================
class AddPetPage extends StatefulWidget {
  const AddPetPage({super.key});

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增寵物', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('為您的寶貝建立檔案', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            const Text('請輸入寵物的名稱，方便日後在儀表板查看狀態。', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(hintText: '寵物名稱 (例如: 布丁)', prefixIcon: const Icon(Icons.cruelty_free), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 30),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF4CA1AF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () async {
                String inputName = _nameController.text.trim();
                if (inputName.isNotEmpty) {
                  globalPetList.add(inputName);
                  await SettingsService.savePetList(globalPetList);
                  
                  // ★ 新增寵物後，也要載入它的預設設定
                  currentSelectedPet = inputName;
                  final settings = await SettingsService.loadPetSettings(inputName);
                  globalApiBaseUrl = settings['apiUrl'];
                  globalFeedThreshold = settings['feedThreshold'];
                  globalWaterThreshold = settings['waterThreshold'];

                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainNavigation()), (route) => false);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入寵物名稱')));
                }
              },
              child: const Text('確認綁定並進入系統', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. 主導覽架構
// ==========================================
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    DashboardPage(),
    StatisticsPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() { _selectedIndex = index; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))]),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF4CA1AF),
            unselectedItemColor: Colors.grey.shade400,
            showUnselectedLabels: true,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_rounded), label: '監控'),
              BottomNavigationBarItem(icon: Icon(Icons.insert_chart_rounded), label: '數據'),
              BottomNavigationBarItem(icon: Icon(Icons.tune_rounded), label: '設定'),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. 首頁儀表板 (Dashboard)
// ==========================================
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _timer;
  String lightLux = '--';
  double feedWeight = 0.0;
  int waterAdc = 0;
  String errorMessage = '';
  
  final double maxFeedWeight = 2000.0;
  final double maxWaterAdc = 4095.0;

  @override
  void initState() {
    super.initState();
    _fetchSensorData();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchSensorData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSensorData() async {
    try {
      final baseUrl = globalApiBaseUrl.endsWith('/') ? globalApiBaseUrl : '$globalApiBaseUrl/';
      final url = Uri.parse('${baseUrl}sensors');
      
      final response = await http.get(
        url,
        headers: {"ngrok-skip-browser-warning": "true"},
      ).timeout(const Duration(seconds: 5));

      if (!mounted) return; 

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final luxValue = data['light'];
          lightLux = (luxValue is num) ? luxValue.toStringAsFixed(1) : '--';
          feedWeight = (data['weight'] ?? 0.0).toDouble();
          
          final waterRaw = data['water'];
          waterAdc = waterRaw != null ? (int.tryParse(waterRaw.toString().split('.').first) ?? 0) : 0;
          
          errorMessage = '';
        });
      } else {
        setState(() { errorMessage = '寵物艙系統回應異常 (錯誤碼: ${response.statusCode})，請稍後再試。'; });
      }
    } catch (e) {
      if (!mounted) return; 
      setState(() { errorMessage = '無法連線至寵物艙，請前往「設定」檢查 API 網址是否正確，或確認手機網路是否通暢。'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    double feedPercentage = (feedWeight / maxFeedWeight).clamp(0.0, 1.0);
    double waterPercentage = (waterAdc / maxWaterAdc).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('$currentSelectedPet的寵物艙', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCameraView(),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 15.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                  child: Text(errorMessage, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 25),
            const Text('環境指標', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSmartTile(Icons.thermostat_rounded, '溫度', '26.5', '°C', Colors.orange)),
                const SizedBox(width: 15),
                Expanded(child: _buildSmartTile(Icons.water_drop_rounded, '濕度', '55', '%', Colors.blue)),
                const SizedBox(width: 15),
                Expanded(child: _buildSmartTile(Icons.wb_sunny_rounded, '亮度', lightLux, ' Lux', Colors.amber)),
              ],
            ),
            const SizedBox(height: 25),
            const Text('飲食狀態', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]),
              child: Column(
                children: [
                  _buildLevelIndicator(Icons.pets, '飼料剩餘', '${feedWeight.toStringAsFixed(1)} g', feedPercentage, Colors.brown),
                  const SizedBox(height: 20),
                  _buildLevelIndicator(Icons.local_drink, '飲用水位', 'ADC: $waterAdc', waterPercentage, Colors.lightBlue),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() => const WhepVideoWidget();

  Widget _buildSmartTile(IconData icon, String title, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLevelIndicator(IconData icon, String label, String valueText, double percentage, Color color) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(valueText)]),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: percentage, minHeight: 12, backgroundColor: color.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation<Color>(color)),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 5. 數據統計頁面 (Statistics)
// ==========================================
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('歷史數據分析', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(child: Text('圖表載入中...')),
    );
  }
}

// ==========================================
// 6. 設定頁面 (Settings & Threshold Control)
// ==========================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = globalApiBaseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showThresholdDialog(String title, double currentValue, Function(double) onSave) {
    double tempValue = currentValue;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('目前閾值: ${tempValue.toInt()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4CA1AF))),
                  const SizedBox(height: 20),
                  Slider(
                    value: tempValue,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: const Color(0xFF4CA1AF),
                    onChanged: (value) {
                      setDialogState(() { tempValue = value; });
                    },
                  ),
                  const Text('當剩餘量低於此數值時，系統將發送警報', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                FilledButton(
                  onPressed: () {
                    onSave(tempValue);
                    Navigator.pop(context);
                    setState(() {});
                  },
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4CA1AF)),
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showApiUrlDialog() {
    _urlController.text = globalApiBaseUrl;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設定 API 網址'),
        content: TextField(controller: _urlController, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final url = _urlController.text.trim();
              setState(() { globalApiBaseUrl = url; });
              
              // ★ 這裡改了！儲存的時候，會連同「當前的寵物名字」一起存進去
              SettingsService.saveApiUrl(currentSelectedPet, url);
              
              Navigator.pop(context);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('系統設定', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Text('連線設定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          _buildSettingsCard(
            child: ListTile(
              leading: const Icon(Icons.wifi, color: Colors.blue),
              title: const Text('API 伺服器網址'),
              subtitle: Text(globalApiBaseUrl, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.edit),
              onTap: _showApiUrlDialog,
            ),
          ),
          const SizedBox(height: 25),
          const Text('警報閾值設定 (%)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          _buildSettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shopping_basket_outlined, color: Colors.brown),
                  title: const Text('飼料剩餘警報'),
                  subtitle: const Text('剩餘量過低時提醒'),
                  trailing: Text('${globalFeedThreshold.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CA1AF), fontSize: 16)),
                  onTap: () => _showThresholdDialog('設定飼料警報閾值', globalFeedThreshold, (v) {
                    globalFeedThreshold = v;
                    SettingsService.saveFeedThreshold(currentSelectedPet, v); // ★ 同理，存給對應寵物
                  }),
                ),
                const Divider(height: 1, indent: 50),
                ListTile(
                  leading: const Icon(Icons.opacity, color: Colors.blue),
                  title: const Text('水位深度警報'),
                  subtitle: const Text('飲水不足時提醒'),
                  trailing: Text('${globalWaterThreshold.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CA1AF), fontSize: 16)),
                  onTap: () => _showThresholdDialog('設定水位警報閾值', globalWaterThreshold, (v) {
                    globalWaterThreshold = v;
                    SettingsService.saveWaterThreshold(currentSelectedPet, v); // ★ 同理，存給對應寵物
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text('其他', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          _buildSettingsCard(
            child: const ListTile(
              leading: Icon(Icons.group_add_outlined, color: Colors.green),
              title: Text('家庭成員共享'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: child,
    );
  }
}