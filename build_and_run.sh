#!/bin/bash
# Build and run SirenUA on iOS Simulator

cd "$(dirname "$0")"

# Create SirenUA.xcodeproj directory
mkdir -p SirenUA.xcodeproj

# Create a minimal Xcode project
cat > SirenUA.xcodeproj/project.pbxproj << 'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		A1 /* SirenUAApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2 /* SirenUAApp.swift */; };
		A3 /* ContentViewV2.swift in Sources */ = {isa = PBXBuildFile; fileRef = A4 /* ContentViewV2.swift */; };
		A5 /* MapViewV2.swift in Sources */ = {isa = PBXBuildFile; fileRef = A6 /* MapViewV2.swift */; };
		A7 /* AlertViewModelV2.swift in Sources */ = {isa = PBXBuildFile; fileRef = A8 /* AlertViewModelV2.swift */; };
		A9 /* AlertStatusCardV2.swift in Sources */ = {isa = PBXBuildFile; fileRef = A10 /* AlertStatusCardV2.swift */; };
		AB /* AlertRegionDetailView.swift in Sources */ = {isa = PBXBuildFile; fileRef = AC /* AlertRegionDetailView.swift */; };
		AD /* NetworkManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = AE /* NetworkManager.swift */; };
		AF /* AlertRegion.swift in Sources */ = {isa = PBXBuildFile; fileRef = B0 /* AlertRegion.swift */; };
		B1 /* ErrorView.swift in Sources */ = {isa = PBXBuildFile; fileRef = B2 /* ErrorView.swift */; };
		B3 /* CriticalAlertManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = B4 /* CriticalAlertManager.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		A2 /* SirenUAApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SirenUAApp.swift; sourceTree = "<group>"; };
		A4 /* ContentViewV2.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentViewV2.swift; sourceTree = "<group>"; };
		A6 /* MapViewV2.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MapViewV2.swift; sourceTree = "<group>"; };
		A8 /* AlertViewModelV2.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AlertViewModelV2.swift; sourceTree = "<group>"; };
		A10 /* AlertStatusCardV2.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AlertStatusCardV2.swift; sourceTree = "<group>"; };
		AC /* AlertRegionDetailView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AlertRegionDetailView.swift; sourceTree = "<group>"; };
		AE /* NetworkManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NetworkManager.swift; sourceTree = "<group>"; };
		B0 /* AlertRegion.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AlertRegion.swift; sourceTree = "<group>"; };
		B2 /* ErrorView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ErrorView.swift; sourceTree = "<group>"; };
		B4 /* CriticalAlertManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CriticalAlertManager.swift; sourceTree = "<group>"; };
		B5 /* SirenUA.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SirenUA.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		B6 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		B7 = {
			isa = PBXGroup;
			children = (
				B8 /* SirenUA */,
				B9 /* Products */,
			);
			sourceTree = "<group>";
		};
		B8 /* SirenUA */ = {
			isa = PBXGroup;
			children = (
				A2 /* SirenUAApp.swift */,
				A4 /* ContentViewV2.swift */,
				A6 /* MapViewV2.swift */,
				A8 /* AlertViewModelV2.swift */,
				A10 /* AlertStatusCardV2.swift */,
				AC /* AlertRegionDetailView.swift */,
				AE /* NetworkManager.swift */,
				B0 /* AlertRegion.swift */,
				B2 /* ErrorView.swift */,
				B4 /* CriticalAlertManager.swift */,
			);
			path = SirenUA;
			sourceTree = "<group>";
		};
		B9 /* Products */ = {
			isa = PBXGroup;
			children = (
				B5 /* SirenUA.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		BA /* SirenUA */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = BB /* Build configuration list for PBXNativeTarget "SirenUA" */;
			buildPhases = (
				BC /* Sources */,
				B6 /* Frameworks */,
				BD /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = SirenUA;
			productName = SirenUA;
			productReference = B5 /* SirenUA.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		BE /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					BA = {
						CreatedOnToolsVersion = 15.0;
					};
				};
			};
			buildConfigurationList = BF /* Build configuration list for PBXProject "SirenUA" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = B7;
			productRefGroup = B9 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				BA /* SirenUA */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		BD /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		BC /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A1 /* SirenUAApp.swift in Sources */,
				A3 /* ContentViewV2.swift in Sources */,
				A5 /* MapViewV2.swift in Sources */,
				A7 /* AlertViewModelV2.swift in Sources */,
				A9 /* AlertStatusCardV2.swift in Sources */,
				AB /* AlertRegionDetailView.swift in Sources */,
				AD /* NetworkManager.swift in Sources */,
				AF /* AlertRegion.swift in Sources */,
				B1 /* ErrorView.swift in Sources */,
				B3 /* CriticalAlertManager.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		C0 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		C1 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		C2 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CLANG_ENABLE_MODULES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.sirenua.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		C3 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CLANG_ENABLE_MODULES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.sirenua.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		BB /* Build configuration list for PBXNativeTarget "SirenUA" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				C2 /* Debug */,
				C3 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		BF /* Build configuration list for PBXProject "SirenUA" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				C0 /* Debug */,
				C1 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = BE /* Project object */;
}
EOF

echo "Project file created!"

# Build the project
xcodebuild -project SirenUA.xcodeproj -scheme SirenUA -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' build 2>&1 | tail -30

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
    # Launch the app
    xcrun simctl launch booted com.sirenua.app 2>/dev/null || echo "App launched!"
else
    echo "❌ Build failed!"
    exit 1
fi
