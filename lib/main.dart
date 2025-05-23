import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define light theme
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: Colors.blue.shade100,
      cardColor: Colors.white, // Card color for light mode (white)
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.black87),
        titleLarge: TextStyle(color: Colors.black87),
        titleMedium: TextStyle(color: Colors.black54),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      // Add more colors or properties as needed for light mode
    );

    // Define dark theme
    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blueGrey,
      scaffoldBackgroundColor: Colors.blueGrey.shade900,
      cardColor: Colors.blueGrey.shade800, // Change this to a darker color
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white70),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white60),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      // Add more colors or properties as needed for dark mode
    );

    return MaterialApp(
      title: 'Weathery',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, // Follow system theme by default
      home: const WeatherScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final String apiKey = "YOUR API KEY HERE";
  Map<String, dynamic>? weatherData;
  String city = "Loading...";
  Position? _currentPosition;
  bool isLoading = true;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;

  // Hourly forecast data
  List<dynamic> hourlyForecast = [];

  // Get gradient colors based on weather condition
  List<Color> getWeatherGradient(String weatherMain) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.light) {
      // Lighter gradients for light mode
      switch (weatherMain.toLowerCase()) {
        case 'clear':
          return [Colors.lightBlue.shade200, Colors.blue.shade400];
        case 'clouds':
          return [Colors.blueGrey.shade200, Colors.blueGrey.shade400];
        case 'rain':
          return [Colors.grey.shade400, Colors.blueGrey.shade600];
        case 'snow':
          return [Colors.blueGrey.shade100, Colors.cyan.shade200];
        case 'thunderstorm':
          return [Colors.blueGrey.shade600, Colors.blueGrey.shade900];
        case 'drizzle':
          return [Colors.cyan.shade200, Colors.blue.shade300];
        case 'mist':
        case 'fog':
          return [Colors.blueGrey.shade300, Colors.blueGrey.shade500];
        default:
          return [Colors.lightBlue.shade200, Colors.blue.shade400];
      }
    } else {
      // Darker gradients for dark mode (keeping your previous darker ones)
      switch (weatherMain.toLowerCase()) {
        case 'clear':
          return [const Color(0xFF1A2980), const Color(0xFF26D0CE)];
        case 'clouds':
          return [const Color(0xFF2C3E50), const Color(0xFF3498DB)];
        case 'rain':
          return [const Color(0xFF373B44), const Color(0xFF4286f4)];
        case 'snow':
          return [const Color(0xFF757F9A), const Color(0xFFD7DDE8)];
        case 'thunderstorm':
          return [const Color(0xFF232526), const Color(0xFF414345)];
        case 'drizzle':
          return [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)];
        case 'mist':
        case 'fog':
          return [const Color(0xFF606C88), const Color(0xFF3F4C6B)];
        default:
          return [
            const Color.fromARGB(255, 10, 40, 88),
            const Color.fromARGB(255, 19, 74, 179),
          ];
      }
    }
  }

  // Get weather icon based on condition
  String getWeatherIcon(String iconCode) {
    return "https://openweathermap.org/img/wn/$iconCode@2x.png";
  }

  // Get weather background image
  String getWeatherBackground(String weatherMain) {
    switch (weatherMain.toLowerCase()) {
      case 'clear':
        return 'https://images.unsplash.com/photo-1504608524841-42fe6f032b4b?w=800';
      case 'clouds':
        return 'https://images.unsplash.com/photo-1501630834273-4b5604d2ee31?w=800';
      case 'rain':
        return 'https://images.unsplash.com/photo-1501691223387-dd0506c89ac8?w=800';
      case 'snow':
        return 'https://images.unsplash.com/photo-1418985991508-e47386d96a71?w=800';
      case 'thunderstorm':
        return 'https://images.unsplash.com/photo-1501426026826-31c667bdf23d?w=800';
      default:
        return 'https://images.unsplash.com/photo-1504608524841-42fe6f032b4b?w=800';
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Please enable location services.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. Please enable them in settings.',
      );
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw Exception('Location permissions are denied.');
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      final url =
          "https://api.openweathermap.org/geo/1.0/direct?q=$query&limit=5&appid=$apiKey";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          searchResults =
              data
                  .map(
                    (item) => {
                      'name': item['name'],
                      'country': item['country'],
                      'lat': item['lat'],
                      'lon': item['lon'],
                    },
                  )
                  .toList();
          isSearching = false;
        });
      } else {
        throw Exception('Failed to search locations');
      }
    } catch (e) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error searching locations: ${e.toString()}")),
        );
      }
    }
  }

  // Fetch hourly forecast using /data/2.5/forecast endpoint (5-day / 3-hour data)
  Future<void> fetchHourlyForecast(double lat, double lon) async {
    try {
      final url =
          "https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        setState(() {
          hourlyForecast =
              decoded['list'] ??
              []; // Data is in the 'list' key for this endpoint
          // This endpoint provides 5-day forecast with data every 3 hours
        });
        print('Fetched forecast data: \\${hourlyForecast.length} items');
      } else {
        setState(() {
          hourlyForecast = [];
        });
        print('Failed to fetch forecast data: status \\${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        hourlyForecast = [];
      });
      print('Exception fetching forecast data: \\${e.toString()}');
    }
  }

  Future<void> fetchWeatherByLocation() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      weatherData = null;
      hourlyForecast = [];
    });

    try {
      final position = await _getCurrentLocation();
      setState(() {
        _currentPosition = position;
      });
      final lat = position.latitude;
      final lon = position.longitude;

      await fetchWeatherData(lat, lon);
      await fetchHourlyForecast(lat, lon);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
        weatherData = null;
        hourlyForecast = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> fetchWeatherData(double lat, double lon) async {
    try {
      final url =
          "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        setState(() {
          weatherData = decoded;
          city = decoded['name'] ?? "Your Location";
          isLoading = false;
        });
        // Also fetch forecasts for searched location
        await fetchHourlyForecast(lat, lon);
      } else {
        throw Exception(
          "Failed to fetch weather data. Please try again later.",
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  String getFormattedTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('hh:mm a').format(date);
  }

  String getFormattedDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('EEE, MMM d').format(date);
  }

  String getWindDirection(int degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  @override
  void initState() {
    super.initState();
    fetchWeatherByLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildWeatherDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    // Define icon colors for different weather parameters
    Color getIconColor() {
      if (brightness == Brightness.light) {
        switch (icon) {
          case Icons.thermostat_outlined:
            return Colors.orange.shade700;
          case Icons.water_drop_outlined:
            return Colors.blue.shade700;
          case Icons.air_outlined:
          case Icons.explore_outlined:
            return Colors.teal.shade700;
          case Icons.speed_outlined:
            return Colors.purple.shade700;
          case Icons.visibility_outlined:
            return Colors.indigo.shade700;
          case Icons.cloud_outlined:
            return Colors.blueGrey.shade700;
          case Icons.sunny:
            return Colors.amber.shade700;
          case Icons.nightlight_round:
            return Colors.indigo.shade700;
          default:
            return Colors.blue.shade700;
        }
      } else {
        switch (icon) {
          case Icons.thermostat_outlined:
            return Colors.orange.shade300;
          case Icons.water_drop_outlined:
            return Colors.blue.shade300;
          case Icons.air_outlined:
          case Icons.explore_outlined:
            return Colors.teal.shade300;
          case Icons.speed_outlined:
            return Colors.purple.shade300;
          case Icons.visibility_outlined:
            return Colors.indigo.shade300;
          case Icons.cloud_outlined:
            return Colors.blueGrey.shade300;
          case Icons.sunny:
            return Colors.amber.shade300;
          case Icons.nightlight_round:
            return Colors.indigo.shade300;
          default:
            return Colors.blue.shade300;
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      margin: const EdgeInsets.only(right: 0),
      decoration: BoxDecoration(
        color: brightness == Brightness.light ? Colors.white : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: getIconColor(), size: 32),
              const SizedBox(width: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color:
                        brightness == Brightness.light
                            ? Colors.black
                            : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color:
                    brightness == Brightness.light
                        ? Colors.black
                        : (theme.textTheme.titleLarge?.color ?? Colors.white),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherSection({
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              color:
                  brightness == Brightness.light
                      ? Colors.black
                      : Colors.white, // Black in light, white in dark
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Column(
          children:
              children
                  .map(
                    (child) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: child,
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String getMoonPhase(double phase) {
    if (phase == 0 || phase == 1) return 'New Moon';
    if (phase < 0.25) return 'Waxing Crescent';
    if (phase == 0.25) return 'First Quarter';
    if (phase < 0.5) return 'Waxing Gibbous';
    if (phase == 0.5) return 'Full Moon';
    if (phase < 0.75) return 'Waning Gibbous';
    if (phase == 0.75) return 'Last Quarter';
    return 'Waning Crescent';
  }

  Widget _buildHourlyForecast() {
    print('Building Hourly Forecast Widget: \\${hourlyForecast.length} items');
    if (hourlyForecast.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final now = DateTime.now();
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule,
                color:
                    brightness == Brightness.light
                        ? Colors.blue.shade700
                        : Colors.blue.shade300,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Hourly Forecast',
                style: TextStyle(
                  color: theme.textTheme.titleLarge!.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount:
                  hourlyForecast.length > 12 ? 12 : hourlyForecast.length,
              itemBuilder: (context, index) {
                final hour = hourlyForecast[index];
                final dt = DateTime.fromMillisecondsSinceEpoch(
                  hour['dt'] * 1000,
                );
                final isNow = index == 0 || dt.hour == now.hour;
                final temp = hour['main']?['temp']?.round() ?? 0;
                final icon = hour['weather']?[0]['icon'] ?? '01d';
                final pop = ((hour['pop'] ?? 0.0) * 100).round();
                return Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isNow ? Colors.blue.shade700 : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isNow
                              ? 'Now'
                              : DateFormat('ha').format(dt).toLowerCase(),
                          style: TextStyle(
                            color:
                                isNow
                                    ? Colors.white
                                    : theme
                                        .textTheme
                                        .titleMedium!
                                        .color, // Use theme text color
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$temp°',
                        style: TextStyle(
                          color:
                              theme
                                  .textTheme
                                  .titleLarge!
                                  .color, // Use theme text color
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Image.network(
                        getWeatherIcon(icon),
                        width: 32,
                        height: 32,
                        errorBuilder:
                            (context, error, stackTrace) => Icon(
                              Icons.cloud,
                              color: theme.textTheme.bodyMedium!.color,
                              size: 32,
                            ), // Use theme text color
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$pop%',
                        style: TextStyle(
                          color:
                              theme
                                  .textTheme
                                  .bodyMedium!
                                  .color, // Use theme text color
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final weatherMain =
        weatherData != null &&
                weatherData!['weather'] != null &&
                weatherData!['weather'].isNotEmpty
            ? weatherData!['weather'][0]['main']
            : 'clear';

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor, // Use theme background color
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: getWeatherGradient(weatherMain),
            begin: Alignment.topLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: SafeArea(
          child:
              isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                  : errorMessage != null
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: theme.textTheme.titleLarge!.color,
                          ), // Use theme text color
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: fetchWeatherByLocation,
                          child: Text(
                            'Retry',
                            style: TextStyle(color: theme.primaryColor),
                          ), // Use theme primary color
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: fetchWeatherByLocation,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            // Location Search
                            Container(
                              decoration: BoxDecoration(
                                color:
                                    brightness == Brightness.light
                                        ? const Color.fromARGB(
                                          255,
                                          250,
                                          250,
                                          250,
                                        )
                                        : theme
                                            .cardColor, // Use theme card color in dark mode
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    style: TextStyle(
                                      color:
                                          brightness == Brightness.light
                                              ? Colors.black
                                              : Colors.white,
                                    ),
                                    textAlignVertical: TextAlignVertical.center,
                                    decoration: InputDecoration(
                                      hintText: 'Search',
                                      hintStyle: TextStyle(
                                        color:
                                            brightness == Brightness.light
                                                ? Colors.black.withOpacity(0.7)
                                                : Colors.white.withOpacity(0.7),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color:
                                            brightness == Brightness.light
                                                ? Colors.black
                                                : Colors.white,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          Icons.my_location,
                                          color:
                                              brightness == Brightness.light
                                                  ? Colors.black
                                                  : Colors.white,
                                        ),
                                        onPressed: fetchWeatherByLocation,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 16,
                                            horizontal: 16,
                                          ),
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      if (value.length >= 3) {
                                        searchLocation(value);
                                      } else {
                                        setState(() {
                                          searchResults = [];
                                        });
                                      }
                                    },
                                  ),
                                  if (searchResults.isNotEmpty)
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 200,
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: searchResults.length,
                                        itemBuilder: (context, index) {
                                          final result = searchResults[index];
                                          return ListTile(
                                            title: Text(
                                              '${result['name']}, ${result['country']}',
                                              style: TextStyle(
                                                color:
                                                    brightness ==
                                                            Brightness.light
                                                        ? Colors.black
                                                        : Colors.white,
                                              ),
                                            ),
                                            onTap: () async {
                                              await fetchWeatherData(
                                                result['lat'],
                                                result['lon'],
                                              );
                                              setState(() {
                                                searchResults = [];
                                                _searchController.clear();
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (weatherData != null &&
                                weatherData!['main'] != null)
                              Column(
                                children: [
                                  Text(
                                    "${weatherData!['main']['temp']?.round() ?? 0}°C",
                                    style: TextStyle(
                                      fontSize: 70,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          brightness == Brightness.light
                                              ? Colors.white
                                              : (theme
                                                      .textTheme
                                                      .titleLarge
                                                      ?.color ??
                                                  Colors
                                                      .white), // White in light mode, theme color in dark
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        city,
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat(
                                      'EEEE, h:mm a',
                                    ).format(DateTime.now()),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 30),

                            // Hourly Forecast Section
                            _buildHourlyForecast(),

                            // Current Weather Details
                            if (weatherData != null &&
                                weatherData!['main'] != null) ...[
                              // Temperature Section Card
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      brightness == Brightness.light
                                          ? const Color.fromARGB(
                                            255,
                                            250,
                                            250,
                                            250,
                                          )
                                          : theme
                                              .cardColor, // Use theme card color in dark mode
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildWeatherSection(
                                  title: "Temperature",
                                  children: [
                                    _buildWeatherDetail(
                                      icon: Icons.thermostat_outlined,
                                      label: "Current",
                                      value:
                                          "${weatherData!['main']['temp']?.round() ?? 0}°C",
                                    ),
                                    _buildWeatherDetail(
                                      icon: Icons.thermostat_outlined,
                                      label: "Feels Like",
                                      value:
                                          "${weatherData!['main']['feels_like']?.round() ?? 0}°C",
                                    ),
                                    // Dew Point from OneCall API, may not be in /weather response
                                    if (weatherData!['main']?['dew_point'] !=
                                        null)
                                      _buildWeatherDetail(
                                        icon: Icons.water_drop_outlined,
                                        label: "Dew Point",
                                        value:
                                            "${weatherData!['main']?['dew_point']?.round() ?? 0}°C",
                                      ),
                                  ],
                                ),
                              ),

                              // Wind Section Card
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      brightness == Brightness.light
                                          ? const Color.fromARGB(
                                            255,
                                            250,
                                            250,
                                            250,
                                          )
                                          : theme
                                              .cardColor, // Use theme card color in dark mode
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildWeatherSection(
                                  title: "Wind",
                                  children: [
                                    _buildWeatherDetail(
                                      icon: Icons.air_outlined,
                                      label: "Speed",
                                      value:
                                          "${weatherData!['wind']?['speed'] ?? 0} m/s",
                                    ),
                                    // Wind Gust from OneCall API, may not be in /weather response
                                    if (weatherData!['wind']?['gust'] != null)
                                      _buildWeatherDetail(
                                        icon: Icons.air_outlined,
                                        label: "Gust",
                                        value:
                                            "${weatherData!['wind']?['gust']?.toStringAsFixed(1) ?? 0} m/s",
                                      ),
                                    _buildWeatherDetail(
                                      icon: Icons.explore_outlined,
                                      label: "Direction",
                                      value: getWindDirection(
                                        weatherData!['wind']?['deg'] ?? 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Atmospheric Section Card
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      brightness == Brightness.light
                                          ? const Color.fromARGB(
                                            255,
                                            250,
                                            250,
                                            250,
                                          )
                                          : theme
                                              .cardColor, // Use theme card color in dark mode
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildWeatherSection(
                                  title: "Atmospheric",
                                  children: [
                                    _buildWeatherDetail(
                                      icon: Icons.water_drop_outlined,
                                      label: "Humidity",
                                      value:
                                          "${weatherData!['main']?['humidity'] ?? 0}%",
                                    ),
                                    _buildWeatherDetail(
                                      icon: Icons.speed_outlined,
                                      label: "Pressure",
                                      value:
                                          "${weatherData!['main']?['pressure'] ?? 0} hPa",
                                    ),
                                    _buildWeatherDetail(
                                      icon: Icons.visibility_outlined,
                                      label: "Visibility",
                                      value:
                                          "${((weatherData!['visibility'] ?? 0) / 1000).toStringAsFixed(1)} km",
                                    ),
                                  ],
                                ),
                              ),

                              // Sky Conditions Section Card
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      brightness == Brightness.light
                                          ? const Color.fromARGB(
                                            255,
                                            250,
                                            250,
                                            250,
                                          )
                                          : theme
                                              .cardColor, // Use theme card color in dark mode
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildWeatherSection(
                                  title: "Sky Conditions",
                                  children: [
                                    if (weatherData!['clouds']?['all'] != null)
                                      _buildWeatherDetail(
                                        icon: Icons.cloud_outlined,
                                        label: "Clouds",
                                        value:
                                            "${weatherData!['clouds']?['all'] ?? 0}%",
                                      ),
                                    // UV Index from OneCall API, not in /weather response
                                    // if (weatherData!['daily'] != null && weatherData!['daily'].isNotEmpty)
                                    //   _buildWeatherDetail(
                                    //     icon: Icons.wb_sunny_outlined,
                                    //     label: "UV Index",
                                    //     value: "${weatherData!['daily'][0]['uvi']?.toStringAsFixed(1) ?? 0}",
                                    //   ),
                                  ],
                                ),
                              ),

                              // Time Section Card
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      brightness == Brightness.light
                                          ? const Color.fromARGB(
                                            255,
                                            250,
                                            250,
                                            250,
                                          )
                                          : theme
                                              .cardColor, // Use theme card color in dark mode
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildWeatherSection(
                                  title: "Time",
                                  children: [
                                    if (weatherData!['sys']?['sunrise'] != null)
                                      _buildWeatherDetail(
                                        icon: Icons.sunny,
                                        label: "Sunrise",
                                        value: getFormattedTime(
                                          weatherData!['sys']?['sunrise'] ?? 0,
                                        ),
                                      ),
                                    if (weatherData!['sys']?['sunset'] != null)
                                      _buildWeatherDetail(
                                        icon: Icons.nightlight_round,
                                        label: "Sunset",
                                        value: getFormattedTime(
                                          weatherData!['sys']?['sunset'] ?? 0,
                                        ),
                                      ),
                                    // Moon Phase from OneCall API, not in /weather response
                                    // if (weatherData!['daily'] != null && weatherData!['daily'].isNotEmpty)
                                    //   _buildWeatherDetail(
                                    //     icon: Icons.nightlight_round,
                                    //     label: "Moon Phase",
                                    //     value: getMoonPhase(weatherData!['daily'][0]['moon_phase'] ?? 0),
                                    //   ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
        ),
      ),
    );
  }
}
