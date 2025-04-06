# TUI项目文件结构与功能说明

## 模型与数据管理

1. **Photo.swift**
   - 主要功能：定义照片数据结构
   - 核心内容：`Photo`结构体，包含照片的各项属性（ID、标题、路径、EXIF信息等）

2. **SQLiteManager.swift**
   - 主要功能：数据库操作的核心类
   - 主要方法：
     - `addPhoto`：添加照片记录
     - `getPhoto`：获取单张照片
     - `getAllPhotos`：获取所有照片
     - `searchPhotos`：搜索照片
     - `updatePhotoRecord`：更新照片信息
     - `deletePhotoRecord`：删除照片记录

3. **SQLiteManagerExtensions.swift**
   - 主要功能：SQLiteManager的扩展方法
   - 主要方法：
     - `getPhotosByCamera`：获取指定相机拍摄的照片
     - `getPhotosByLens`：获取指定镜头拍摄的照片
     - `getLensInfo`：获取镜头使用统计
     - `addBulkPhoto`：批量添加照片

4. **SQLiteManagerBirdReport.swift**
   - 主要功能：鸟类观察相关的数据库操作扩展
   - 主要方法：
     - `getBirdPhotosStats`：获取鸟类照片统计
     - `getYearlyBirdSpecies`：获取年度鸟类物种列表
     - `getBirdSpeciesRanking`：获取鸟类物种排名

5. **HotSearchManager.swift**
   - 主要功能：管理热门搜索记录
   - 主要方法：
     - `addHotSearch`：添加搜索关键词到热门搜索
     - `getHotSearches`：获取热门搜索关键词列表

6. **BirdCountCache.swift**
   - 主要功能：缓存鸟类统计数据
   - 主要方法：
     - `update`：更新缓存
     - `clear`：清除缓存
     - `shouldUpdate`：判断是否需要更新缓存

7. **NationalViewCache.swift**
   - 主要功能：缓存国家视图数据
   - 主要方法：与BirdCountCache类似

8. **CountryCodeManager.swift**
   - 主要功能：管理国家代码和名称
   - 主要方法：
     - `getCountryCode`：根据国家名称获取代码
     - `getCountryName`：根据代码获取国家名称

9. **QuoteModels.swift**
   - 主要功能：定义引用数据结构和管理器
   - 主要类：
     - `Quote`：引用数据结构
     - `QuoteManager`：管理摄影引言

## 导入与处理

10. **PhotoExtractor.swift**
    - 主要功能：从图片中提取EXIF信息
    - 主要方法：`extractAndSaveBulkPhotoInfo`：提取并保存照片信息

11. **ImportUtilities.swift**
    - 主要功能：导入工具函数
    - 主要方法：
      - `generateThumbnail`：生成缩略图
      - `geocodeLocation`：地理编码位置

12. **BulkImportHelper.swift**
    - 主要功能：批量导入助手
    - 主要方法：`importAsset`：导入资源

13. **BulkImportManager.swift**
    - 主要功能：批量导入管理器
    - 主要方法：`importPhotos`：从相册导入照片

14. **ImportErrors.swift**
    - 主要功能：定义导入过程中的错误类型
    - 主要内容：`TuiImporterError`和`ImportError`枚举

15. **PhotoSaver.swift**
    - 主要功能：保存照片到文件系统
    - 主要方法：`saveBulkPhoto`：保存批量照片

16. **ImagePicker.swift**
    - 主要功能：图片选择器组件
    - 主要内容：`ImagePicker`结构体，实现UIViewControllerRepresentable

## 备份与恢复

17. **BackupManager.swift**
    - 主要功能：管理备份与恢复
    - 主要方法：
      - `createBackup`：创建备份
      - `restoreBackup`：恢复备份
      - `restoreDefaultBackup`：恢复默认备份

## 视图组件

18. **HeadBarView.swift**
    - 主要功能：顶部导航栏视图
    - 主要内容：`HeadBarView`结构体和`FlagView`结构体

19. **BottomBarView.swift**
    - 主要功能：底部导航栏视图
    - 主要内容：`BottomBarView`结构体

20. **StarRatingView.swift**
    - 主要功能：星级评分视图
    - 主要内容：`StarRatingView`结构体

21. **WebView.swift**
    - 主要功能：Web视图包装器
    - 主要内容：`WebView`结构体，实现UIViewRepresentable

22. **ZoomInView.swift**
    - 主要功能：照片缩放视图
    - 主要内容：`ZoomInView`结构体

23. **PosterView.swift**
    - 主要功能：海报生成视图
    - 主要内容：`PosterView`结构体

24. **SinglePhotoView.swift**
    - 主要功能：单张照片查看器
    - 主要内容：`SinglePhotoView`结构体和`ImageScrollView`类

## 主要功能视图

25. **AddImageView.swift**
    - 主要功能：添加照片界面
    - 主要方法：
      - `loadImage`：加载选择的图片
      - `saveImage`：保存图片到数据库

26. **ContentView.swift**
    - 主要功能：应用主视图
    - 主要方法：
      - `loadImages`：加载图片
      - `loadMoreImages`：加载更多图片

27. **DetailView.swift**
    - 主要功能：照片详情视图
    - 主要内容：`DetailView`结构体
    - 主要方法：
      - `loadPhotos`：加载照片
      - `deletePhoto`：删除照片

28. **EditorView.swift**
    - 主要功能：照片编辑视图
    - 主要方法：
      - `saveImage`：保存编辑后的图片
      - `lookupLocation`：查找地理位置

29. **LandingView.swift**
    - 主要功能：应用启动页面
    - 主要方法：
      - `loadTodaysQuote`：加载今日引言
      - `checkFirstLaunch`：检查是否首次启动

30. **OnboardingView.swift**
    - 主要功能：新用户引导视图
    - 主要内容：分步引导页面

31. **SearchView.swift**
    - 主要功能：搜索界面
    - 主要方法：
      - `performSearch`：执行搜索
      - `loadMore`：加载更多搜索结果

32. **SettingsView.swift**
    - 主要功能：设置界面
    - 主要方法：`saveSettings`：保存设置

33. **BackupView.swift**
    - 主要功能：备份与恢复界面
    - 主要方法：
      - `performBackup`：执行备份
      - `performRestore`：执行恢复

34. **BulkImportView.swift**
    - 主要功能：批量导入界面
    - 主要方法：`startImport`：开始导入

35. **ShareView.swift**
    - 主要功能：分享界面
    - 主要方法：
      - `sharePoster`：分享海报
      - `saveExifInfo`：保存EXIF信息

## 照片浏览视图

36. **CalendarView.swift**
    - 主要功能：日历浏览照片
    - 主要方法：
      - `loadPhotos`：加载指定日期的照片
      - `loadDatesWithPhotos`：加载有照片的日期

37. **CustomCalendarView.swift**
    - 主要功能：自定义日历控件
    - 主要方法：
      - `generateDaysInMonth`：生成月份天数
      - `monthString`：获取月份字符串

38. **CameraDetailView.swift**
    - 主要功能：相机详情视图
    - 主要方法：`loadPhotos`：加载指定相机的照片

39. **LensDetailView.swift**
    - 主要功能：镜头详情视图
    - 主要方法：`loadPhotos`：加载指定镜头的照片

40. **CameraCountView.swift**
    - 主要功能：相机统计视图
    - 主要方法：`loadCameraCounts`：加载相机统计

41. **LensCountView.swift**
    - 主要功能：镜头统计视图
    - 主要方法：`loadLensCounts`：加载镜头统计

42. **NationalView.swift**
    - 主要功能：国家列表视图
    - 主要方法：`loadCountries`：加载国家列表

43. **NationalPhotoListView.swift**
    - 主要功能：国家照片列表
    - 主要方法：`loadPhotos`：加载指定国家的照片

44. **LocalityListView.swift**
    - 主要功能：地区列表视图
    - 主要方法：`loadLocalitiesAndBirdSpecies`：加载地区和鸟类物种

45. **LocalityPhotoListView.swift**
    - 主要功能：地区照片列表
    - 主要方法：`loadPhotos`：加载指定地区的照片

46. **MapView.swift**
    - 主要功能：地图视图
    - 主要内容：`MapView`结构体，展示照片拍摄位置

47. **ObjectNameView.swift**
    - 主要功能：按对象名称浏览照片
    - 主要方法：`loadPhotos`：加载指定对象名称的照片

## 鸟类观察功能

48. **BirdCountView.swift**
    - 主要功能：鸟类统计视图
    - 主要方法：`loadBirdCounts`：加载鸟类统计

49. **BirdNameListView.swift**
    - 主要功能：鸟类名称列表
    - 主要方法：
      - `loadBirdInfo`：加载鸟类信息
      - `performSearch`：搜索鸟类

50. **LocalityBirdCountView.swift**
    - 主要功能：地区鸟类统计
    - 主要方法：`loadBirdListWithCache`：加载地区鸟类列表

51. **YearlyBirdReportView.swift**
    - 主要功能：年度鸟类报告
    - 主要方法：`loadYearlyStats`：加载年度统计

## 其他功能视图

52. **ProjectView.swift**
    - 主要功能：365项目视图
    - 主要方法：`calculateStreak`：计算连续拍摄天数

53. **BlogView.swift**
    - 主要功能：博客视图
    - 主要内容：`BlogViewModel`类和`RSSParser`类

54. **BeginnerView.swift**
    - 主要功能：新手指南视图
    - 主要内容：简单的导航组件

55. **HistoryView.swift**
    - 主要功能：拍摄历史视图
    - 主要方法：`loadPhotoStats`：加载照片统计数据

56. **QuotesView.swift**
    - 主要功能：摄影引言视图
    - 主要方法：`loadQuotes`：加载引言

57. **TutorView.swift**
    - 主要功能：教程视图
    - 主要方法：`fetchVideoDetails`：获取视频详情

## 辅助组件与工具

58. **WaterfallView.swift**
    - 主要功能：瀑布流布局组件
    - 主要内容：`WaterfallView`结构体和`WaterfallItemView`结构体

59. **PhotoListView.swift**
    - 主要功能：照片列表组件
    - 主要内容：`PhotoListView`结构体和`PhotoThumbnail`结构体

60. **ReviewView.swift**
    - 主要功能：照片预览组件
    - 主要内容：`ReviewView`结构体

61. **SamedayView.swift**
    - 主要功能：同一天拍摄的照片视图
    - 主要方法：`loadPhotos`：加载同一天的照片

62. **BlockView.swift**
    - 主要功能：块状照片视图组件
    - 主要内容：`BlockView`结构体和`NavigationDestination`枚举

63. **PhotoImageView.swift**
    - 主要功能：照片图像视图组件
    - 主要内容：`PhotoImageView`结构体

64. **EXIFManager.swift**
    - 主要功能：EXIF信息管理
    - 主要方法：
      - `copyEXIFInfo`：复制EXIF信息
      - `formatDate`：格式化日期
      - `exposureInfo`：格式化曝光信息

## 应用入口与配置

65. **TUIApp.swift**
    - 主要功能：应用入口
    - 主要内容：`TUIApp`结构体，定义应用入口点

66. **AppDelegate.swift**
    - 主要功能：应用代理
    - 主要方法：`application(_:didFinishLaunchingWithOptions:)`：应用启动处理

67. **Info.plist**
    - 主要功能：应用配置信息
    - 主要内容：应用权限、URL方案等配置

68. **TUI.entitlements**
    - 主要功能：应用权限配置
    - 主要内容：应用权限配置

69. **Config.xcconfig**
    - 主要功能：外部配置文件
    - 主要内容：API密钥等配置
