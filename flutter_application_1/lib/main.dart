import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'widgets/whep_video_widget.dart';
import 'services/settings_service.dart';

// ==========================================
// 全域變數
// ==========================================
String globalApiBaseUrl = 'http://137.184.181.86:8000/';
double globalFeedThreshold = 20.0;
double globalWaterThreshold = 15.0;
List<String> globalPetList = [];
String currentSelectedPet = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const defaultGoogleServerClientId =
      '500259007502-a9j4411qcak9mjm4t9u2gbn7cof5e5mi.apps.googleusercontent.com';
  const overrideGoogleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  final googleServerClientId = overrideGoogleServerClientId.isEmpty
      ? defaultGoogleServerClientId
      : overrideGoogleServerClientId;
  if (_supportsNativeGoogleSignIn) {
    await GoogleSignIn.instance.initialize(
      serverClientId: googleServerClientId,
    );
  }

  final settings = await SettingsService.load();
  globalApiBaseUrl = settings['apiUrl'];
  globalFeedThreshold = settings['feedThreshold'];
  globalWaterThreshold = settings['waterThreshold'];
  globalPetList = List<String>.from(settings['petList']);

  runApp(const IoTApp());
}

bool get _supportsNativeGoogleSignIn {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const PetSelectionPage();
        }

        return const LoginPage();
      },
    );
  }
}

// ==========================================
// 1. 登入頁面 (Login Page)
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isRegisterMode = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = '請輸入電子郵件與密碼');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyAuthError(e));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = '登入失敗，請稍後再試');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential credential;
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        credential = await _auth.signInWithPopup(googleProvider);
      } else if (_supportsNativeGoogleSignIn) {
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        final authCredential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        credential = await _auth.signInWithCredential(authCredential);
      } else {
        throw FirebaseAuthException(
          code: 'operation-not-allowed',
          message: '這個平台不支援 Google 登入，請改用電子郵件登入。',
        );
      }

      if (credential.user == null && mounted) {
        setState(() => _errorMessage = 'Google 登入未完成');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyAuthError(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Google 登入失敗：${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '電子郵件格式不正確';
      case 'user-disabled':
        return '這個帳號已被停用';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '帳號或密碼不正確';
      case 'email-already-in-use':
        return '這個電子郵件已經註冊';
      case 'weak-password':
        return '密碼強度不足，請至少輸入 6 個字元';
      case 'operation-not-allowed':
        return 'Firebase 尚未啟用這個登入方式';
      case 'popup-closed-by-user':
      case 'canceled':
        return '登入已取消';
      default:
        return e.message ?? '登入失敗，請稍後再試';
    }
  }

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
                const Text(
                  '歡迎回來',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '登入以查看您的智慧寵物艙',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: '電子郵件',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: '密碼',
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 30),

                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF4CA1AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submitWithEmail,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isRegisterMode ? '建立帳號' : '登入',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                if (kIsWeb || _supportsNativeGoogleSignIn) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text(
                      '使用 Google 登入',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isRegisterMode = !_isRegisterMode;
                            _errorMessage = null;
                          });
                        },
                  child: Text(_isRegisterMode ? '已有帳號？改用登入' : '沒有帳號？建立新帳號'),
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
  // 新增：用來記錄真實連線狀態的變數
  bool _isOnline = false;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkDeviceStatus(); // 畫面一載入就偷偷檢查連線
  }

  // 測試連線的函數
  Future<void> _checkDeviceStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStatus = true;
    });

    try {
      final baseUrl = globalApiBaseUrl.endsWith('/')
          ? globalApiBaseUrl
          : '$globalApiBaseUrl/';
      final url = Uri.parse('${baseUrl}sensors');

      final response = await http
          .get(url, headers: {"ngrok-skip-browser-warning": "true"})
          .timeout(const Duration(seconds: 3)); // 3秒沒回應就算離線

      if (mounted) {
        setState(() {
          _isOnline = response.statusCode == 200;
          _isLoadingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOnline = false;
          _isLoadingStatus = false;
        });
      }
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  globalPetList.removeAt(index);
                });
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
      appBar: AppBar(
        title: const Text(
          '選擇寵物',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '您今天要查看哪位寶貝的狀態？',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              // 加入 RefreshIndicator 支援下拉重新整理
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
                          Text(
                            '目前尚未綁定任何寵物艙',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '請點擊下方按鈕新增您的寵物。',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: globalPetList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          // 動態決定狀態文字與顏色
                          String currentStatus = _isLoadingStatus
                              ? '連線偵測中...'
                              : (_isOnline ? '設備已上線' : '設備目前離線');
                          Color statusColor = _isLoadingStatus
                              ? Colors.grey
                              : (_isOnline ? Colors.green : Colors.redAccent);

                          return _buildPetCard(
                            context,
                            index: index,
                            name: globalPetList[index],
                            status: currentStatus,
                            statusColor: statusColor, // 傳遞顏色
                            icon: Icons.pets,
                            color: Colors.orange,
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF4CA1AF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddPetPage()),
                );
              },
              icon: const Icon(Icons.add, color: Color(0xFF4CA1AF)),
              label: const Text(
                '新增寵物艙綁定',
                style: TextStyle(
                  color: Color(0xFF4CA1AF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 接收動態顏色參數
  Widget _buildPetCard(
    BuildContext context, {
    required int index,
    required String name,
    required String status,
    required Color statusColor,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        currentSelectedPet = name;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 套用動態顏色
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 14,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _deletePet(index),
            ),
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
      appBar: AppBar(
        title: const Text(
          '新增寵物',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '為您的寶貝建立檔案',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '請輸入寵物的名稱，方便日後在儀表板查看狀態。',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '寵物名稱 (例如: 布丁)',
                prefixIcon: const Icon(Icons.cruelty_free),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF4CA1AF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () {
                String inputName = _nameController.text.trim();
                if (inputName.isNotEmpty) {
                  globalPetList.add(inputName);
                  SettingsService.savePetList(globalPetList);
                  currentSelectedPet = inputName;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainNavigation(),
                    ),
                    (route) => false,
                  );
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('請輸入寵物名稱')));
                }
              },
              child: const Text(
                '確認綁定並進入系統',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF4CA1AF),
            unselectedItemColor: Colors.grey.shade400,
            showUnselectedLabels: true,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.space_dashboard_rounded),
                label: '監控',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insert_chart_rounded),
                label: '數據',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.tune_rounded),
                label: '設定',
              ),
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
      final baseUrl = globalApiBaseUrl.endsWith('/')
          ? globalApiBaseUrl
          : '$globalApiBaseUrl/';
      final url = Uri.parse('${baseUrl}sensors');

      final response = await http
          .get(url, headers: {"ngrok-skip-browser-warning": "true"})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final luxValue = data['light_lux'] ?? data['light'];
          lightLux = (luxValue is num) ? luxValue.toStringAsFixed(1) : '--';
          feedWeight = (data['weight'] ?? 0.0).toDouble();

          final waterRaw = data['water_adc'] ?? data['water'];
          waterAdc = waterRaw != null
              ? (int.tryParse(waterRaw.toString().split('.').first) ?? 0)
              : 0;

          errorMessage = '';
        });
      } else {
        setState(() {
          errorMessage = '伺服器錯誤: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = '連線失敗: ${e.toString().split('\n').first}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double feedPercentage = (feedWeight / maxFeedWeight).clamp(0.0, 1.0);
    double waterPercentage = (waterAdc / maxWaterAdc).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$currentSelectedPet的寵物艙',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () async {
              if (_supportsNativeGoogleSignIn) {
                try {
                  await GoogleSignIn.instance.signOut();
                } catch (_) {}
              }
              await FirebaseAuth.instance.signOut();
            },
          ),
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
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 25),
            const Text(
              '環境指標',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSmartTile(
                    Icons.thermostat_rounded,
                    '溫度',
                    '26.5',
                    '°C',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildSmartTile(
                    Icons.water_drop_rounded,
                    '濕度',
                    '55',
                    '%',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildSmartTile(
                    Icons.wb_sunny_rounded,
                    '亮度',
                    lightLux,
                    ' Lux',
                    Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              '飲食狀態',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildLevelIndicator(
                    Icons.pets,
                    '飼料剩餘',
                    '${feedWeight.toStringAsFixed(1)} g',
                    feedPercentage,
                    Colors.brown,
                  ),
                  const SizedBox(height: 20),
                  _buildLevelIndicator(
                    Icons.local_drink,
                    '飲用水位',
                    'ADC: $waterAdc',
                    waterPercentage,
                    Colors.lightBlue,
                  ),
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

  Widget _buildSmartTile(
    IconData icon,
    String title,
    String value,
    String unit,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelIndicator(
    IconData icon,
    String label,
    String valueText,
    double percentage,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(label), Text(valueText)],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percentage,
                minHeight: 12,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
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
      appBar: AppBar(
        title: const Text(
          '歷史數據分析',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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

  void _showThresholdDialog(
    String title,
    double currentValue,
    Function(double) onSave,
  ) {
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
                  Text(
                    '目前閾值: ${tempValue.toInt()}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CA1AF),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: tempValue,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: const Color(0xFF4CA1AF),
                    onChanged: (value) {
                      setDialogState(() {
                        tempValue = value;
                      });
                    },
                  ),
                  const Text(
                    '當剩餘量低於此數值時，系統將發送警報',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    onSave(tempValue);
                    Navigator.pop(context);
                    setState(() {});
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4CA1AF),
                  ),
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
        content: TextField(
          controller: _urlController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final url = _urlController.text.trim();
              setState(() {
                globalApiBaseUrl = url;
              });
              SettingsService.saveApiUrl(url);
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
      appBar: AppBar(
        title: const Text(
          '系統設定',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '連線設定',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          _buildSettingsCard(
            child: ListTile(
              leading: const Icon(Icons.wifi, color: Colors.blue),
              title: const Text('API 伺服器網址'),
              subtitle: Text(
                globalApiBaseUrl,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.edit),
              onTap: _showApiUrlDialog,
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            '警報閾值設定 (%)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          _buildSettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.shopping_basket_outlined,
                    color: Colors.brown,
                  ),
                  title: const Text('飼料剩餘警報'),
                  subtitle: const Text('剩餘量過低時提醒'),
                  trailing: Text(
                    '${globalFeedThreshold.toInt()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CA1AF),
                      fontSize: 16,
                    ),
                  ),
                  onTap: () => _showThresholdDialog(
                    '設定飼料警報閾值',
                    globalFeedThreshold,
                    (v) {
                      globalFeedThreshold = v;
                      SettingsService.saveFeedThreshold(v);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 50),
                ListTile(
                  leading: const Icon(Icons.opacity, color: Colors.blue),
                  title: const Text('水位深度警報'),
                  subtitle: const Text('飲水不足時提醒'),
                  trailing: Text(
                    '${globalWaterThreshold.toInt()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CA1AF),
                      fontSize: 16,
                    ),
                  ),
                  onTap: () => _showThresholdDialog(
                    '設定水位警報閾值',
                    globalWaterThreshold,
                    (v) {
                      globalWaterThreshold = v;
                      SettingsService.saveWaterThreshold(v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            '其他',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
