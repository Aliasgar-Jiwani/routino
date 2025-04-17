# Routino 📅

A beautifully designed Flutter application to manage daily tasks and schedules with intuitive notifications and progress tracking.

![Flutter Version](https://img.shields.io/badge/Flutter-%E2%9C%93-blue)
![Hive Storage](https://img.shields.io/badge/Hive-%E2%9C%93-orange)
![Material3](https://img.shields.io/badge/Material3-%E2%9C%93-purple)

---

## Features ✨

- **Task Management**
  - Add/Edit/Delete tasks with custom names, time ranges, and notes
  - Auto-icon assignment based on task type (📚 Study, 💼 Work, etc.)
- **Smart Notifications**

  - 5-minute pre-task reminders
  - Automatic rescheduling for missed notifications
  - Android/iOS permission handling

- **Progress Visualization**

  - Real-time progress bar for daily tasks
  - Current/Upcoming task highlights

- **Multi-Day Support**
  - Weekly schedule organization
  - Quick day-switching via settings

---

## Screenshots 📸

### Splash Screen  
![screen1](ScreenShots/screen1.jpeg =300x)

### Current and Upcoming Tasks  
![screen2](ScreenShots/screen2.jpeg =300x)

### Current Day Task  
![screen3](ScreenShots/screen3.jpeg =300x)

### Setting  
![screen4](ScreenShots/screen4.jpeg =300x)

### Adding New Task  
![screen5](ScreenShots/screen5.jpeg =300x)

---


## Getting Started 🚀

### Prerequisites

- Flutter 3.0+ ([Installation Guide](https://flutter.dev/docs/get-started/install))
- Android Studio/Xcode for platform-specific setup
- Device with API 21+ (Android) or iOS 10+

### Installation

```bash
# Clone repository
git clone https://github.com/Aliasgar-Jiwani/routino.git
cd routino

# Install dependencies
flutter pub get

# Initialize Hive storage
flutter packages pub run build_runner build

# Run the app
flutter run
```

---

## Usage 📝

### Adding Tasks

1. Tap ➕ FAB to open task creation
2. Set day, time, and task details
3. Automatic icon assignment based on task name keywords

### Managing Notifications

- Toggle notifications in Settings tab
- Android requires "Exact Alarm" permission (auto-prompted)

### Viewing Progress

- Progress bar shows daily schedule completion
- Current task highlighted in blue

---

## Technical Details 🛠️

### Key Dependencies

- **State Management**: Provider
- **Storage**: Hive (NoSQL)
- **Notifications**: flutter_local_notifications
- **Date Handling**: timezone, intl

### Platform Notes

- **Android**:
  - Requires `Schedule Exact Alarms` permission (auto-handled)
  - Notification channels configured

---

## Contributing 🤝

1. Fork repository
2. Create feature branch (`git checkout -b feature/fooBar`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push branch (`git push origin feature/fooBar`)
5. Open pull request

---

## License 📄

Distributed under the MIT License. See `LICENSE` for details.

---

Made with ❤️ using Flutter & Material3  
[![GitHub followers](https://img.shields.io/github/followers/YOURUSERNAME.svg?style=social&label=Follow)](https://github.com/Aliasgar-Jiwani)
