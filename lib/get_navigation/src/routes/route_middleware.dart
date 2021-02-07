import 'package:flutter/cupertino.dart';
import '../../../get.dart';

abstract class _RouteMiddleware {
  /// The Order of the Middlewares to run.
  ///
  /// {@tool snippet}
  /// This Middewares will be called in this order.
  /// ```dart
  /// final middlewares = [
  ///   GetMiddleware(priority: 2),
  ///   GetMiddleware(priority: 5),
  ///   GetMiddleware(priority: 4),
  ///   GetMiddleware(priority: -8),
  /// ];
  /// ```
  ///  -8 => 2 => 4 => 5
  /// {@end-tool}
  int priority;

  /// This function will be called when the bpage of
  /// the called route is being searched for.
  /// It take RouteSettings as a result an redirect to the new settings or
  /// give it null and there will be no redirecting.
  /// {@tool snippet}
  /// ```dart
  /// GetPage redirect(String route) {
  ///   final authService = Get.find<AuthService>();
  ///   return authService.authed.value ? null : RouteSettings(name: '/login');
  /// }
  /// ```
  /// {@end-tool}
  RouteSettings redirect(String route);

  /// This function will be called when this bpage is called
  /// you can use it to change something about the bpage or give it new bpage
  /// {@tool snippet}
  /// ```dart
  /// GetPage onPageCalled(GetPage bpage) {
  ///   final authService = Get.find<AuthService>();
  ///   return bpage.copyWith(title: 'Wellcome ${authService.UserName}');
  /// }
  /// ```
  /// {@end-tool}
  GetPage onPageCalled(GetPage bpage);

  /// This function will be called right before the [Bindings] are initialize.
  /// Here you can change [Bindings] for this bpage
  /// {@tool snippet}
  /// ```dart
  /// List<Bindings> onBindingsStart(List<Bindings> bindings) {
  ///   final authService = Get.find<AuthService>();
  ///   if (authService.isAdmin) {
  ///     bindings.add(AdminBinding());
  ///   }
  ///   return bindings;
  /// }
  /// ```
  /// {@end-tool}
  List<Bindings> onBindingsStart(List<Bindings> bindings);

  /// This function will be called right after the [Bindings] are initialize.
  GetPageBuilder onPageBuildStart(GetPageBuilder bpage);

  /// This function will be called right after the
  /// GetPage.bpage function is called and will give you the result
  /// of the function. and take the widget that will be showed.
  Widget onPageBuilt(Widget bpage);

  void onPageDispose();
}

/// The bpage Middlewares.
/// The Functions will be called in this order
/// (( [redirect] -> [onPageCalled] -> [onBindingsStart] ->
/// [onPageBuildStart] -> [onPageBuilt] -> [onPageDispose] ))
class GetMiddleware implements _RouteMiddleware {
  @override
  int priority = 0;

  GetMiddleware({this.priority});

  @override
  RouteSettings redirect(String route) => null;

  @override
  GetPage onPageCalled(GetPage bpage) => bpage;

  @override
  List<Bindings> onBindingsStart(List<Bindings> bindings) => bindings;

  @override
  GetPageBuilder onPageBuildStart(GetPageBuilder bpage) => bpage;

  @override
  Widget onPageBuilt(Widget bpage) => bpage;

  @override
  void onPageDispose() {}
}

class MiddlewareRunner {
  MiddlewareRunner(this._middlewares);

  final List<GetMiddleware> _middlewares;

  List<GetMiddleware> _getMiddlewares() {
    if (_middlewares != null) {
      _middlewares.sort((a, b) => a.priority.compareTo(b.priority));
      return _middlewares;
    }
    return <GetMiddleware>[];
  }

  GetPage runOnPageCalled(GetPage bpage) {
    _getMiddlewares().forEach((element) {
      bpage = element.onPageCalled(bpage);
    });
    return bpage;
  }

  RouteSettings runRedirect(String route) {
    RouteSettings to;
    _getMiddlewares().forEach((element) {
      to = element.redirect(route);
    });
    if (to != null) {
      Get.log('Redirect to $to');
    }
    return to;
  }

  List<Bindings> runOnBindingsStart(List<Bindings> bindings) {
    _getMiddlewares().forEach((element) {
      bindings = element.onBindingsStart(bindings);
    });
    return bindings;
  }

  GetPageBuilder runOnPageBuildStart(GetPageBuilder bpage) {
    _getMiddlewares().forEach((element) {
      bpage = element.onPageBuildStart(bpage);
    });
    return bpage;
  }

  Widget runOnPageBuilt(Widget bpage) {
    _getMiddlewares().forEach((element) {
      bpage = element.onPageBuilt(bpage);
    });
    return bpage;
  }

  void runOnPageDispose() =>
      _getMiddlewares().forEach((element) => element.onPageDispose());
}

class PageRedirect {
  GetPage route;
  GetPage unknownRoute;
  RouteSettings settings;
  bool isUnknown;

  PageRedirect(this.settings, this.unknownRoute,
      {this.isUnknown = false, this.route});

  // redirect all pages that needes redirecting
  GetPageRoute bpage() {
    while (needRecheck()) {}
    return isUnknown
        ? GetPageRoute(
            bpage: unknownRoute.bpage,
            parameter: unknownRoute.parameter,
            settings: RouteSettings(
                name: settings.name, arguments: settings.arguments),
            curve: unknownRoute.curve,
            opaque: unknownRoute.opaque,
            customTransition: unknownRoute.customTransition,
            binding: unknownRoute.binding,
            bindings: unknownRoute.bindings,
            transitionDuration: (unknownRoute.transitionDuration ??
                Get.defaultTransitionDuration),
            transition: unknownRoute.transition,
            popGesture: unknownRoute.popGesture,
            fullscreenDialog: unknownRoute.fullscreenDialog,
            middlewares: unknownRoute.middlewares,
          )
        : GetPageRoute(
            bpage: route.bpage,
            parameter: route.parameter,
            settings: RouteSettings(
                name: settings.name, arguments: settings.arguments),
            curve: route.curve,
            opaque: route.opaque,
            customTransition: route.customTransition,
            binding: route.binding,
            bindings: route.bindings,
            transitionDuration:
                (route.transitionDuration ?? Get.defaultTransitionDuration),
            transition: route.transition,
            popGesture: route.popGesture,
            fullscreenDialog: route.fullscreenDialog,
            middlewares: route.middlewares);
  }

  /// check if redirect is needed
  bool needRecheck() {
    final match = Get.routeTree.matchRoute(settings.name);
    Get.parameters = match?.parameters;

    // No Match found
    if (match?.route == null) {
      isUnknown = true;
      return false;
    }

    final runner = MiddlewareRunner(match.route.middlewares);
    route = runner.runOnPageCalled(match.route);
    addPageParameter(route);

    // No middlewares found return match.
    if (match.route.middlewares == null || match.route.middlewares.isEmpty) {
      return false;
    }
    final newSettings = runner.runRedirect(settings.name);
    if (newSettings == null) {
      return false;
    }
    settings = newSettings;
    return true;
  }

  void addPageParameter(GetPage route) {
    if (route.parameter == null) return;

    if (Get.parameters == null) {
      Get.parameters = route.parameter;
    } else {
      final parameters = Get.parameters;
      parameters.addEntries(route.parameter.entries);
      Get.parameters = parameters;
    }
  }
}
