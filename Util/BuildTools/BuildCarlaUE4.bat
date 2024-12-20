@echo off
setlocal enabledelayedexpansion

rem 这是一个用于为Carla（carla.org）创建二进制文件的BAT脚本。
rem 请在启用了x64 Visual C++ 工具集的cmd中运行它。

set LOCAL_PATH=%~dp0
set FILE_N=-[%~n0]:

rem 打印批处理参数（用于调试）
echo %FILE_N% [Batch params]: %*
rem ============================================================================
rem -- 解析参数 --------------------------------------------------------------
rem ============================================================================

rem 初始化变量
set BUILD_UE4_EDITOR=false        rem 是否构建UE4编辑器
set LAUNCH_UE4_EDITOR=false       rem 是否启动UE4编辑器
set REMOVE_INTERMEDIATE=false     rem 是否移除中间文件
set USE_CARSIM=false              rem 是否使用CarSim
set USE_CHRONO=false              rem 是否使用Chrono
set USE_UNITY=true                rem 是否使用Unity
set CARSIM_STATE="CarSim OFF"     rem CarSim状态
set CHRONO_STATE="Chrono OFF"     rem Chrono状态
set UNITY_STATE="Unity ON"        rem Unity状态
set AT_LEAST_WRITE_OPTIONALMODULES=false rem 是否至少写入可选模块
set EDITOR_FLAGS=""               rem 编辑器标志
set USE_ROS2=false                rem 是否使用ROS2
set ROS2_STATE="Ros2 OFF"         rem ROS2状态

:arg-parse
echo %1
if not "%1"=="" (
    if "%1"=="--editor-flags" (
        set EDITOR_FLAGS=%2       rem 设置编辑器标志
        shift
    )
    if "%1"=="--build" (
        set BUILD_UE4_EDITOR=true rem 设置为构建UE4编辑器
    )
    if "%1"=="--launch" (
        set LAUNCH_UE4_EDITOR=true rem 设置为启动UE4编辑器
    )
    if "%1"=="--clean" (
        set REMOVE_INTERMEDIATE=true rem 设置为移除中间文件
    )
    if "%1"=="--carsim" (
        set USE_CARSIM=true       rem 设置为使用CarSim
    )
    if "%1"=="--chrono" (
        set USE_CHRONO=true       rem 设置为使用Chrono
    )
    if "%1"=="--ros2" (
        set USE_ROS2=true         rem 设置为使用ROS2
    )
    if "%1"=="--no-unity" (
        set USE_UNITY=false       rem 设置为不使用Unity
    )
    if "%1"=="--at-least-write-optionalmodules" (
        set AT_LEAST_WRITE_OPTIONALMODULES=true rem 设置为至少写入可选模块
    )
    if "%1"=="-h" (
        goto help                 rem 跳转到帮助信息
    )
    if "%1"=="--help" (
        goto help                 rem 跳转到帮助信息
    )
    shift                         rem 移动到下一个参数
    goto arg-parse                rem 继续解析参数
)

rem 可以在此处添加实际的构建逻辑和命令
rem 从参数中移除引号
set EDITOR_FLAGS=%EDITOR_FLAGS:"=%

if %REMOVE_INTERMEDIATE% == false (
    if %LAUNCH_UE4_EDITOR% == false (
        if %BUILD_UE4_EDITOR% == false (
            if %AT_LEAST_WRITE_OPTIONALMODULES% == false (
                goto help
            )
        )
    )
)

rem 获取Unreal Engine的根目录
rem 如果未定义UE4_ROOT，则从注册表中查找
if not defined UE4_ROOT (
    set KEY_NAME="HKEY_LOCAL_MACHINE\SOFTWARE\EpicGames\Unreal Engine"
    set VALUE_NAME=InstalledDirectory
    for /f "usebackq tokens=1,2,*" %%A in (`reg query !KEY_NAME! /s /reg:64`) do (
        if "%%A" == "!VALUE_NAME!" (
            set UE4_ROOT=%%C
        )
    )
    if not defined UE4_ROOT goto error_unreal_no_found
)
rem 确保UE4_ROOT的末尾有反斜杠
if not "%UE4_ROOT:~-1%"=="\" set UE4_ROOT=%UE4_ROOT%\

rem 设置Visual Studio解决方案的目录
rem 将ROOT_PATH中的斜杠替换为反斜杠，并拼接上Unreal\CarlaUE4\路径
set UE4_PROJECT_FOLDER=%ROOT_PATH:/=\%Unreal\CarlaUE4\
pushd "%UE4_PROJECT_FOLDER%"

rem 清除由构建系统生成的二进制文件和中间文件
rem
if %REMOVE_INTERMEDIATE% == true (
    rem 删除以下目录
    for %%G in (
        "%UE4_PROJECT_FOLDER%Binaries",
        "%UE4_PROJECT_FOLDER%Build",
        "%UE4_PROJECT_FOLDER%Saved",
        "%UE4_PROJECT_FOLDER%Intermediate",
        "%UE4_PROJECT_FOLDER%Plugins\Carla\Binaries",
        "%UE4_PROJECT_FOLDER%Plugins\Carla\Intermediate",
        "%UE4_PROJECT_FOLDER%Plugins\HoudiniEngine\",
        "%UE4_PROJECT_FOLDER%.vs"
    ) do (
        if exist %%G (
            echo %FILE_N% Cleaning %%G
            rmdir /s/q %%G
        )
    )

    rem 删除以下文件
    for %%G in (
        "%UE4_PROJECT_FOLDER%CarlaUE4.sln"
    ) do (
        if exist %%G (
            echo %FILE_N% Cleaning %%G
            del %%G
        )
    )
)

rem 构建Carla编辑器
rem

set OMNIVERSE_PATCH_FOLDER=%ROOT_PATH%Util\Patches\omniverse_4.26\
set OMNIVERSE_PLUGIN_FOLDER=%UE4_ROOT%Engine\Plugins\Marketplace\NVIDIA\Omniverse\
if exist %OMNIVERSE_PLUGIN_FOLDER% (
    set OMNIVERSE_PLUGIN_INSTALLED="Omniverse ON"
    xcopy /Y /S /I "%OMNIVERSE_PATCH_FOLDER%USDCARLAInterface.h" "%OMNIVERSE_PLUGIN_FOLDER%Source\OmniverseUSD\Public\" > NUL
    xcopy /Y /S /I "%OMNIVERSE_PATCH_FOLDER%USDCARLAInterface.cpp" "%OMNIVERSE_PLUGIN_FOLDER%Source\OmniverseUSD\Private\" > NUL
) else (
    set OMNIVERSE_PLUGIN_INSTALLED="Omniverse OFF"
)

if %USE_CARSIM% == true (
    python %ROOT_PATH%Util/BuildTools/enable_carsim_to_uproject.py -f="%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject" -e
    set CARSIM_STATE="CarSim ON"
) else (
    python %ROOT_PATH%Util/BuildTools/enable_carsim_to_uproject.py -f="%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    set CARSIM_STATE="CarSim OFF"
)
if %USE_CHRONO% == true (
    set CHRONO_STATE="Chrono ON"
) else (
    set CHRONO_STATE="Chrono OFF"
)
if %USE_ROS2% == true (
    set ROS2_STATE="Ros2 ON"
) else (
    set ROS2_STATE="Ros2 OFF"
)
if %USE_UNITY% == true (
    set UNITY_STATE="Unity ON"
) else (
    set UNITY_STATE="Unity OFF"
)
set OPTIONAL_MODULES_TEXT=%CARSIM_STATE% %CHRONO_STATE% %ROS2_STATE% %OMNIVERSE_PLUGIN_INSTALLED% %UNITY_STATE%
echo %OPTIONAL_MODULES_TEXT% > "%ROOT_PATH%Unreal/CarlaUE4/Config/OptionalModules.ini"

rem 检查是否构建Unreal Editor
if %BUILD_UE4_EDITOR% == true (
    echo %FILE_N% Building Unreal Editor...

    call "%UE4_ROOT%Engine\Build\BatchFiles\Build.bat"^
        CarlaUE4Editor^
        Win64^
        Development^
        -WaitMutex^
        -FromMsBuild^
        "%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    if errorlevel 1 goto bad_exit

    call "%UE4_ROOT%Engine\Build\BatchFiles\Build.bat"^
        CarlaUE4^
        Win64^
        Development^
        -WaitMutex^
        -FromMsBuild^
        "%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    if errorlevel 1 goto bad_exit
)

rem 启动Carla Editor

if %LAUNCH_UE4_EDITOR% == true (
    echo %FILE_N% Launching Unreal Editor...
    call "%UE4_ROOT%\Engine\Binaries\Win64\UE4Editor.exe"^
        "%UE4_PROJECT_FOLDER%CarlaUE4.uproject" %EDITOR_FLAGS%
    if %errorlevel% neq 0 goto error_build
)

goto good_exit

rem ============================================================================
rem -- Messages and Errors -----------------------------------------------------
rem ============================================================================

:help
    echo Build LibCarla.
    echo "Usage: %FILE_N% [-h^|--help] [--build] [--launch] [--clean]"
    goto good_exit

:error_build
    echo.rem用于输出一个空行，增加输出的可读性间隔
    echo %FILE_N% [ERROR] There was a problem building CarlaUE4.rem 输出包含变量%FILE_N%（可能是文件名之类的预定义变量）和CarlaUE4构建出错的信息
    echo %FILE_N%         Please go to "Carla\Unreal\CarlaUE4", right click on rem 给用户提示操作步骤
    echo %FILE_N%         "CarlaUE4.uproject" and select:r
    echo %FILE_N%         "Generate Visual Studio project files"rem 告知用户进入特定目录，找到CarlaUE4.uproject文件，右键点击并选择生成VS项目文件，可能是因为之前构建问题源于项目文件损坏或不完整
    echo %FILE_N%         Open de generated "CarlaUE4.sln" and try to manually compile it rem提示用户打开生成的CarlaUE4.sln文件并手动编译，以便检查错误原因
    echo %FILE_N%         and check what is causing the error.
    goto bad_exit
rem  跳转到名为bad_exit的标签处，bad_exit标签可能定义了出错时的清理或结束脚本的操作（此处未显示具体内容）
:good_exit
    endlocal
    exit /b 0

:bad_exit
    endlocal
    exit /b %errorlevel%

:error_unreal_no_found
    echo.
    echo %FILE_N% [ERROR] Unreal Engine not detected
    goto bad_exit
