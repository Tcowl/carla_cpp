// Copyright (c) 2017 Computer Vision Center (CVC) at the Universitat Autonoma
// de Barcelona (UAB).
//1
// 这项工作受到 MIT 许可证的条款保护。
// 请参阅<https://opensource.org/licenses/MIT>以获得副本。

#include "carla/client/detail/ActorFactory.h"
// 包含 "carla/client/detail/ActorFactory.h" 头文件。
// 通常这个头文件里会定义与 Actor 工厂相关的类、函数等内容，可能用于创建游戏世界（例如 Carla 模拟器中的虚拟世界）里的各种角色（如车辆、行人等），是 carla/client/detail 模块中很重要的一部分。
#include "carla/Logging.h"// 包含 "carla/Logging.h" 头文件，一般用于实现日志记录相关的功能，比如在程序运行过程中输出各种级别的日志信息（调试、警告、错误等），方便开发人员排查问题以及了解程序运行状态。
#include "carla/StringUtil.h"// 包含 "carla/StringUtil.h" 头文件，大概率提供了一些字符串处理相关的工具函数，像字符串的分割、拼接、格式化等操作
#include "carla/client/Actor.h"// 包含 "carla/client/Actor.h" 头文件，Actor 类应该是 Carla 模拟器客户端中表示游戏世界里各种角色实体（比如车辆、行人、交通信号灯等）的基类，定义了这些角色通用的一些属性和行为等基础内容。
#include "carla/client/LaneInvasionSensor.h"// 包含 "carla/client/LaneInvasionSensor.h" 头文件，推测是用于定义检测车道入侵情况的传感器相关类，可能包含传感
#include "carla/client/ServerSideSensor.h"// 包含 "carla/client/ServerSideSensor.h" 头文件，从名字来看，应该是与服务器端的传感器相关的类定义所在，可能涉及到服务器端对传感器数据的管理、分发等功能，与客户端的传感器交互等方面有紧密联系。
#ifdef RSS_ENABLED
#include "carla/rss/RssSensor.h"
#endif// 如果定义了 RSS_ENABLED 宏（通常用于条件编译，开启或关闭特定功能模块），则包含 "carla/rss/RssSensor.h" 头文件。
// 猜测这个头文件里定义的 RssSensor 类和某种基于 RSS（可能是具体某个领域的专业术语缩写，比如在自动驾驶安全相关场景下的一种安全机制）的传感器相关，用于实现相应的检测等功能。
#include "carla/client/TrafficLight.h"// 包含 "carla/client/TrafficLight.h" 头文件，用于定义交通信号灯相关的类，包含交通信号灯的状态表示（如红灯、绿灯、黄灯等）、控制逻辑以及和游戏世界交互等功能相关的代码。
#include "carla/client/TrafficSign.h"// 包含 "carla/client/TrafficSign.h" 头文件，里面应该是定义了交通标志相关的类，例如不同类型交通标志（停车标志、限速标志等）的表示、识别以及它们对游戏世界中角色的影响等相关功能代码。
#include "carla/client/Vehicle.h"// 包含 "carla/client/Vehicle.h" 头文件，用于定义车辆相关的类，包含车辆的属性（如速度、位置、方向等）、操作（如加速、刹车、转向等）以及和其他车辆、交通设施交互等相关的代码内容。
#include "carla/client/Walker.h"// 包含 "carla/client/Walker.h" 头文件，这里的 Walker 大概率表示行人，这个头文件定义了行人相关的类，比如行人的
#include "carla/client/WalkerAIController.h"// 包含 "carla/client/WalkerAIController.h" 头文件，从名字看应该是用于控制行人自动行走行为的人工智能控制器相关类的
#include "carla/client/World.h"// 包含 "carla/client/World.h" 头文件，用于定义游戏世界相关的类，包含整个虚拟世界的状态维护（如所有角色的位置、状态等）、时间推
#include "carla/client/detail/Client.h"// 包含 "carla/client/detail/Client.h" 头文件，这里的 Client 类可能是与 Carla 模拟器客户端连接、通信等功能相关的

#include <rpc/config.h>// 包含 <rpc/config.h> 头文件，可能是和远程过程调用（RPC）的配置相关，比如设置 RPC 通信的一些参数（端口号、协议等）、启用或禁用某些特性等相关的代码都可能在这个头文件所涉及的模块里定义。
#include <rpc/rpc_error.h>// 包含 <rpc/rpc_error.h> 头文件，通常用于处理在远程过程调用过程中出现的各种错误情况，定义了错误类型、错误码以及相应的处理函数等

#include <exception>// 包含 <exception> 头文件，用于处理 C++ 程序中的异常情况，提供了基本的异常类以及相关的处理机制，使得代码可以通过抛出和捕获异常来应对运行时出现的意外情况。

namespace carla {// 以下是命名空间 carla 的定义，在 C++ 中命名空间用于避免不同模块或者库之间的命名冲突，将相关的类、函数、变量等都放在同
namespace client {  // 这是 carla 命名空间下的 client 子命名空间，意味着这里面的内容更具体地和 Carla 模拟器客户端相关的功能有关，例如客户端操作世界中的各种对象等功能代码一般会放在这个子命名空间下。
namespace detail { //这是 client 子命名空间下的 detail 子命名空间，通常用于放置一些内部实现的、不希望外部直接访问的代码细节，比如一些辅助类、私有函数等，起到了信息隐藏和模块化的作用。

  // 无法对 deleter 抛出异常；与 std::unique_ptr 不同，deleter
  // (std|boost)::shared_ptr 的 deleter 即使受管指针为空也会被调用。
    // 结构体：GarbageCollector，管理 Actor 的生命周期并处理销毁逻辑。
  struct GarbageCollector {
      // 操作符重载：自定义 deleter 函数，用于在 shared_ptr 销毁时执行清理操作。
    void operator()(::carla::client::Actor *ptr) const noexcept {
      if ((ptr != nullptr) && ptr->IsAlive()) {
        try {
            // 销毁 Actor，释放资源
          ptr->Destroy();
          delete ptr;
        } catch (const ::rpc::timeout &timeout) {
            // 捕捉到超时错误时记录日志
          log_error(timeout.what());
          log_error(
              "timeout while trying to garbage collect Actor",
              ptr->GetDisplayId(),
              "actor hasn't been removed from the simulation");
        } catch (const std::exception &e) {
            // 捕捉到其他标准异常时记录日志并终止程序
          log_critical(
              "exception thrown while trying to garbage collect Actor",
              ptr->GetDisplayId(),
              e.what());
          std::terminate();// 终止程序
        } catch (...) {
            // 捕捉到未知异常时记录日志并终止程序
          log_critical(
              "unknown exception thrown while trying to garbage collect an Actor :",
              ptr->GetDisplayId());
          std::terminate();
        }
      }
    }
  };

  // 模板函数：根据传入的 Actor 初始化参数和垃圾回收策略创建 Actor 实例。
// ActorT 是 Actor 类型的模板参数，init 是 ActorInitializer，gc 是垃圾回收策略。
  template <typename ActorT>
  static auto MakeActorImpl(ActorInitializer init, GarbageCollectionPolicy gc) {
    if (gc == GarbageCollectionPolicy::Enabled) {
        // 启用垃圾回收时，创建并返回一个带有 GarbageCollector 的 shared_ptr
      return SharedPtr<ActorT>{new ActorT(std::move(init)), GarbageCollector()};
    }
    DEBUG_ASSERT(gc == GarbageCollectionPolicy::Disabled);// 确保禁用垃圾回收
    return SharedPtr<ActorT>{new ActorT(std::move(init))};// 否则直接返回普通的 shared_ptr
  }

  // ActorFactory 类的成员函数：创建不同类型的 Actor 实例。
// episode: 当前场景的 EpisodeProxy，代表仿真中的当前环境。
// description: rpc::Actor，包含 Actor 的描述信息。
// gc: 垃圾回收策略，决定是否启用垃圾回收。
  SharedPtr<Actor> ActorFactory::MakeActor(
      EpisodeProxy episode,
      rpc::Actor description,
      GarbageCollectionPolicy gc) {
      // 创建 ActorInitializer 实例，传递给具体 Actor 构造函数
    auto init = ActorInitializer{description, episode};
    // 判断传入的 Actor 描述信息，创建对应类型的 Actor 实例
    if (description.description.id == "sensor.other.lane_invasion") {
        // 创建车道入侵传感器实例
      return MakeActorImpl<LaneInvasionSensor>(std::move(init), gc);
#ifdef RSS_ENABLED
    } else if (description.description.id == "sensor.other.rss") {
      return MakeActorImpl<RssSensor>(std::move(init), gc);
#endif
    } else if (description.HasAStream()) {
        // 如果描述信息表示该 Actor 是服务端传感器，创建 ServerSideSensor 实例
      return MakeActorImpl<ServerSideSensor>(std::move(init), gc);
    } else if (StringUtil::StartsWith(description.description.id, "vehicle.")) {
      return MakeActorImpl<Vehicle>(std::move(init), gc);
    } else if (StringUtil::StartsWith(description.description.id, "walker.")) {
      return MakeActorImpl<Walker>(std::move(init), gc);
    } else if (StringUtil::StartsWith(description.description.id, "traffic.traffic_light")) {
      return MakeActorImpl<TrafficLight>(std::move(init), gc);
    } else if (StringUtil::StartsWith(description.description.id, "traffic.")) {
      return MakeActorImpl<TrafficSign>(std::move(init), gc);
    } else if (description.description.id == "controller.ai.walker") {
      return MakeActorImpl<WalkerAIController>(std::move(init), gc);
    }
    return MakeActorImpl<Actor>(std::move(init), gc);
  }

} // namespace detail
} // namespace client
} // namespace carla
