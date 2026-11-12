#!/usr/bin/env python3
"""生成 SuperWeb.xcodeproj（project.pbxproj + 共享 scheme）。

手写 pbxproj 容易漏引用，这里用脚本保证：
- 每个 UUID 唯一且 24 位十六进制
- 每个 PBXBuildFile 的 fileRef 都存在
- Sources 阶段覆盖全部 .swift 文件
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT_NAME = "SuperWeb"
BUNDLE_ID = "com.superweb.browser"
DEPLOYMENT_TARGET = "15.0"

GROUPS = {
    "Browser": [
        "AddressBarView.swift",
        "BrowseListViewController.swift",
        "BrowserToolbar.swift",
        "BrowserViewController.swift",
        "DownloadsViewController.swift",
        "ErrorView.swift",
        "ProgressBarView.swift",
        "SettingsViewController.swift",
        "StartPageView.swift",
        "TabGridViewController.swift",
    ],
    "Model": [
        "AdBlocker.swift",
        "BrowserURL.swift",
        "DownloadManager.swift",
        "HistoryStore.swift",
        "SearchEngine.swift",
        "SessionStore.swift",
        "Settings.swift",
        "Tab.swift",
        "TabManager.swift",
        "UserAgent.swift",
    ],
}

ROOT_FILES = ["AppDelegate.swift", "SceneDelegate.swift", "Theme.swift", "Info.plist"]
RESOURCES = ["Assets.xcassets"]

_counter = 0


def uid() -> str:
    global _counter
    _counter += 1
    return f"{_counter:024X}"


# UUID 池
ids = {
    "root_group": uid(),
    "products_group": uid(),
    "app_group": uid(),
    "project": uid(),
    "target": uid(),
    "product_ref": uid(),
    "sources_phase": uid(),
    "frameworks_phase": uid(),
    "resources_phase": uid(),
    "project_config_list": uid(),
    "target_config_list": uid(),
    "project_debug": uid(),
    "project_release": uid(),
    "target_debug": uid(),
    "target_release": uid(),
}

file_refs = {}   # 相对路径 -> fileRef uuid
build_files = {}  # 相对路径 -> buildFile uuid
group_ids = {}

for name in GROUPS:
    group_ids[name] = uid()
group_ids["Resources"] = uid()

for name in ROOT_FILES:
    file_refs[name] = uid()
for name in RESOURCES:
    file_refs[name] = uid()

swift_rel_paths = []
for name in ROOT_FILES:
    if name.endswith(".swift"):
        swift_rel_paths.append(name)
for group, files in GROUPS.items():
    for name in files:
        rel = f"{group}/{name}"
        file_refs[rel] = uid()
        swift_rel_paths.append(rel)

for rel in swift_rel_paths:
    build_files[rel] = uid()

# 资源文件（Assets.xcassets）也进 Resources 阶段
resource_build = uid()

lines = []
add = lines.append

add("// !$*UTF8*$!")
add("{")
add("\tarchiveVersion = 1;")
add("\tclasses = {")
add("\t};")
add("\tobjectVersion = 56;")
add("\tobjects = {")
add("")

# PBXBuildFile
add("/* Begin PBXBuildFile section */")
for rel in swift_rel_paths:
    add(f"\t\t{build_files[rel]} /* {Path(rel).name} in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {file_refs[rel]}; }};")
add(f"\t\t{resource_build} /* Assets.xcassets in Resources */ = "
    f"{{isa = PBXBuildFile; fileRef = {file_refs['Assets.xcassets']}; }};")
add("/* End PBXBuildFile section */")
add("")

# PBXFileReference
add("/* Begin PBXFileReference section */")
add(f"\t\t{ids['product_ref']} /* {PROJECT_NAME}.app */ = "
    "{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; "
    f"path = {PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for rel, file_id in file_refs.items():
    name = Path(rel).name
    if name.endswith(".swift"):
        kind = "sourcecode.swift"
    elif name == "Info.plist":
        kind = "text.plist.xml"
    elif name.endswith(".xcassets"):
        kind = "folder.assetcatalog"
    else:
        kind = "text"
    path = Path(rel).name
    add(f"\t\t{file_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {kind}; "
        f"path = {path}; sourceTree = \"<group>\"; }};")
add("/* End PBXFileReference section */")
add("")

# PBXFrameworksBuildPhase
add("/* Begin PBXFrameworksBuildPhase section */")
add(f"\t\t{ids['frameworks_phase']} /* Frameworks */ = {{")
add("\t\t\tisa = PBXFrameworksBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add("/* End PBXFrameworksBuildPhase section */")
add("")

# PBXGroup
add("/* Begin PBXGroup section */")
add(f"\t\t{ids['root_group']} = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
add(f"\t\t\t\t{ids['app_group']} /* {PROJECT_NAME} */,")
add(f"\t\t\t\t{ids['products_group']} /* Products */,")
add("\t\t\t);")
add("\t\t\tsourceTree = \"<group>\";")
add("\t\t};")

add(f"\t\t{ids['products_group']} /* Products */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
add(f"\t\t\t\t{ids['product_ref']} /* {PROJECT_NAME}.app */,")
add("\t\t\t);")
add("\t\t\tname = Products;")
add("\t\t\tsourceTree = \"<group>\";")
add("\t\t};")

add(f"\t\t{ids['app_group']} /* {PROJECT_NAME} */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
for name in ROOT_FILES:
    add(f"\t\t\t\t{file_refs[name]} /* {name} */,")
for group in ["Browser", "Model", "Resources"]:
    add(f"\t\t\t\t{group_ids[group]} /* {group} */,")
add("\t\t\t);")
add(f"\t\t\tpath = {PROJECT_NAME};")
add("\t\t\tsourceTree = \"<group>\";")
add("\t\t};")

for group, files in GROUPS.items():
    add(f"\t\t{group_ids[group]} /* {group} */ = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    for name in files:
        add(f"\t\t\t\t{file_refs[f'{group}/{name}']} /* {name} */,")
    add("\t\t\t);")
    add(f"\t\t\tpath = {group};")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")

add(f"\t\t{group_ids['Resources']} /* Resources */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
add(f"\t\t\t\t{file_refs['Assets.xcassets']} /* Assets.xcassets */,")
add("\t\t\t);")
add("\t\t\tpath = Resources;")
add("\t\t\tsourceTree = \"<group>\";")
add("\t\t};")
add("/* End PBXGroup section */")
add("")

# PBXNativeTarget
add("/* Begin PBXNativeTarget section */")
add(f"\t\t{ids['target']} /* {PROJECT_NAME} */ = {{")
add("\t\t\tisa = PBXNativeTarget;")
add(f"\t\t\tbuildConfigurationList = {ids['target_config_list']} /* Build configuration list for PBXNativeTarget \"{PROJECT_NAME}\" */;")
add("\t\t\tbuildPhases = (")
add(f"\t\t\t\t{ids['sources_phase']} /* Sources */,")
add(f"\t\t\t\t{ids['frameworks_phase']} /* Frameworks */,")
add(f"\t\t\t\t{ids['resources_phase']} /* Resources */,")
add("\t\t\t);")
add("\t\t\tbuildRules = (")
add("\t\t\t);")
add("\t\t\tdependencies = (")
add("\t\t\t);")
add(f"\t\t\tname = {PROJECT_NAME};")
add(f"\t\t\tproductName = {PROJECT_NAME};")
add(f"\t\t\tproductReference = {ids['product_ref']} /* {PROJECT_NAME}.app */;")
add("\t\t\tproductType = \"com.apple.product-type.application\";")
add("\t\t};")
add("/* End PBXNativeTarget section */")
add("")

# PBXProject
add("/* Begin PBXProject section */")
add(f"\t\t{ids['project']} /* Project object */ = {{")
add("\t\t\tisa = PBXProject;")
add("\t\t\tattributes = {")
add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
add("\t\t\t\tLastSwiftUpdateCheck = 1500;")
add("\t\t\t\tLastUpgradeCheck = 1500;")
add("\t\t\t\tTargetAttributes = {")
add(f"\t\t\t\t\t{ids['target']} = {{")
add("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
add("\t\t\t\t\t};")
add("\t\t\t\t};")
add("\t\t\t};")
add(f"\t\t\tbuildConfigurationList = {ids['project_config_list']} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;")
add("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
add("\t\t\tdevelopmentRegion = en;")
add("\t\t\thasScannedForEncodings = 0;")
add("\t\t\tknownRegions = (")
add("\t\t\t\ten,")
add("\t\t\t\tBase,")
add("\t\t\t);")
add(f"\t\t\tmainGroup = {ids['root_group']};")
add(f"\t\t\tproductRefGroup = {ids['products_group']} /* Products */;")
add("\t\t\tprojectDirPath = \"\";")
add("\t\t\tprojectRoot = \"\";")
add("\t\t\ttargets = (")
add(f"\t\t\t\t{ids['target']} /* {PROJECT_NAME} */,")
add("\t\t\t);")
add("\t\t};")
add("/* End PBXProject section */")
add("")

# PBXResourcesBuildPhase
add("/* Begin PBXResourcesBuildPhase section */")
add(f"\t\t{ids['resources_phase']} /* Resources */ = {{")
add("\t\t\tisa = PBXResourcesBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
add(f"\t\t\t\t{resource_build} /* Assets.xcassets in Resources */,")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add("/* End PBXResourcesBuildPhase section */")
add("")

# PBXSourcesBuildPhase
add("/* Begin PBXSourcesBuildPhase section */")
add(f"\t\t{ids['sources_phase']} /* Sources */ = {{")
add("\t\t\tisa = PBXSourcesBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
for rel in swift_rel_paths:
    add(f"\t\t\t\t{build_files[rel]} /* {Path(rel).name} in Sources */,")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add("/* End PBXSourcesBuildPhase section */")
add("")

project_common = [
    "ALWAYS_SEARCH_USER_PATHS = NO;",
    "CLANG_ANALYZER_NONNULL = YES;",
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;",
    "CLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";",
    "CLANG_ENABLE_MODULES = YES;",
    "CLANG_ENABLE_OBJC_ARC = YES;",
    "CLANG_ENABLE_OBJC_WEAK = YES;",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;",
    "CLANG_WARN_BOOL_CONVERSION = YES;",
    "CLANG_WARN_COMMA = YES;",
    "CLANG_WARN_CONSTANT_CONVERSION = YES;",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;",
    "CLANG_WARN_DOCUMENTATION_COMMENTS = YES;",
    "CLANG_WARN_EMPTY_BODY = YES;",
    "CLANG_WARN_ENUM_CONVERSION = YES;",
    "CLANG_WARN_INFINITE_RECURSION = YES;",
    "CLANG_WARN_INT_CONVERSION = YES;",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;",
    "CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;",
    "CLANG_WARN_STRICT_PROTOTYPES = YES;",
    "CLANG_WARN_SUSPICIOUS_MOVE = YES;",
    "CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;",
    "CLANG_WARN_UNREACHABLE_CODE = YES;",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;",
    "COPY_PHASE_STRIP = NO;",
    "ENABLE_STRICT_OBJC_MSGSEND = YES;",
    "ENABLE_USER_SCRIPT_SANDBOXING = YES;",
    "GCC_C_LANGUAGE_STANDARD = gnu17;",
    "GCC_NO_COMMON_BLOCKS = YES;",
    "GCC_WARN_64_TO_32_BIT_CONVERSION = YES;",
    "GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;",
    "GCC_WARN_UNDECLARED_SELECTOR = YES;",
    "GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;",
    "GCC_WARN_UNUSED_FUNCTION = YES;",
    "GCC_WARN_UNUSED_VARIABLE = YES;",
    "LOCALIZATION_PREFERS_STRING_CATALOGS = YES;",
    f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};",
    "MTL_FAST_MATH = YES;",
    "SDKROOT = iphoneos;",
]

target_common = [
    "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;",
    "CODE_SIGN_STYLE = Automatic;",
    "CURRENT_PROJECT_VERSION = 1;",
    "DEVELOPMENT_ASSET_PATHS = \"\";",
    "ENABLE_PREVIEWS = YES;",
    "GENERATE_INFOPLIST_FILE = NO;",
    f"INFOPLIST_FILE = {PROJECT_NAME}/Info.plist;",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;",
    "LD_RUNPATH_SEARCH_PATHS = (",
    "\t\"$(inherited)\",",
    "\t\"@executable_path/Frameworks\",",
    ");",
    "MARKETING_VERSION = 1.0.0;",
    f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
    "PRODUCT_NAME = \"$(TARGET_NAME)\";",
    "SWIFT_EMIT_LOC_STRINGS = YES;",
    "SWIFT_VERSION = 5.0;",
    "TARGETED_DEVICE_FAMILY = \"1,2\";",
]

add("/* Begin XCBuildConfiguration section */")


def emit_config(config_id, name, settings):
    add(f"\t\t{config_id} /* {name} */ = {{")
    add("\t\t\tisa = XCBuildConfiguration;")
    add("\t\t\tbuildSettings = {")
    for setting in settings:
        add(f"\t\t\t\t{setting}")
    add("\t\t\t};")
    add(f"\t\t\tname = {name};")
    add("\t\t};")


emit_config(ids["project_debug"], "Debug", project_common + [
    "DEBUG_INFORMATION_FORMAT = dwarf;",
    "ENABLE_TESTABILITY = YES;",
    "GCC_DYNAMIC_NO_PIC = NO;",
    "GCC_OPTIMIZATION_LEVEL = 0;",
    "GCC_PREPROCESSOR_DEFINITIONS = (",
    "\t\"DEBUG=1\",",
    "\t\"$(inherited)\",",
    ");",
    "ONLY_ACTIVE_ARCH = YES;",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";",
    "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";",
])

emit_config(ids["project_release"], "Release", project_common + [
    "DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";",
    "ENABLE_NS_ASSERTIONS = NO;",
    "SWIFT_COMPILATION_MODE = wholemodule;",
    "VALIDATE_PRODUCT = YES;",
])

emit_config(ids["target_debug"], "Debug", target_common + [
    "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";",
])

emit_config(ids["target_release"], "Release", target_common + [
])

add("/* End XCBuildConfiguration section */")
add("")

# XCConfigurationList
add("/* Begin XCConfigurationList section */")
for list_id, label, debug_id, release_id in [
    (ids["project_config_list"], f"PBXProject \"{PROJECT_NAME}\"", ids["project_debug"], ids["project_release"]),
    (ids["target_config_list"], f"PBXNativeTarget \"{PROJECT_NAME}\"", ids["target_debug"], ids["target_release"]),
]:
    add(f"\t\t{list_id} /* Build configuration list for {label} */ = {{")
    add("\t\t\tisa = XCConfigurationList;")
    add("\t\t\tbuildConfigurations = (")
    add(f"\t\t\t\t{debug_id} /* Debug */,")
    add(f"\t\t\t\t{release_id} /* Release */,")
    add("\t\t\t);")
    add("\t\t\tdefaultConfigurationIsVisible = 0;")
    add("\t\t\tdefaultConfigurationName = Release;")
    add("\t\t};")
add("/* End XCConfigurationList section */")
add("\t};")
add(f"\trootObject = {ids['project']} /* Project object */;")
add("}")

pbxproj_path = ROOT / f"{PROJECT_NAME}.xcodeproj" / "project.pbxproj"
pbxproj_path.parent.mkdir(parents=True, exist_ok=True)
pbxproj_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

# 共享 scheme（CI 里 xcodebuild -scheme 需要它）
scheme_dir = ROOT / f"{PROJECT_NAME}.xcodeproj" / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
buildable = (
    f'            <BuildableReference\n'
    f'               BuildableIdentifier = "primary"\n'
    f'               BlueprintIdentifier = "{ids["target"]}"\n'
    f'               BuildableName = "{PROJECT_NAME}.app"\n'
    f'               BlueprintName = "{PROJECT_NAME}"\n'
    f'               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">\n'
    f'            </BuildableReference>\n'
)
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
{buildable}         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{buildable}      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{buildable}      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
(scheme_dir / f"{PROJECT_NAME}.xcscheme").write_text(scheme, encoding="utf-8")

# 校验：所有 24 位 UUID 引用都能在定义处找到
import re

text = pbxproj_path.read_text(encoding="utf-8")
defined = set(re.findall(r"^\t\t([0-9A-F]{24}) ", text, flags=re.MULTILINE))
referenced = set(re.findall(r"\b([0-9A-F]{24})\b", text))
missing = referenced - defined
print(f"定义 UUID: {len(defined)}，引用到的 UUID: {len(referenced)}")
if missing:
    raise SystemExit(f"存在悬空引用: {sorted(missing)}")
print(f"已生成 {pbxproj_path}")
print(f"已生成 {scheme_dir / (PROJECT_NAME + '.xcscheme')}")
print(f"Swift 文件: {len(swift_rel_paths)} 个")
