<!DOCTYPE html>
<html>
<head>
    <title>{TR_PAGE_TITLE}</title>
    <meta charset="{THEME_CHARSET}">
    <meta name="robots" content="nofollow, noindex">
    <link rel="shortcut icon" href="{THEME_ASSETS_PATH}/images/favicon.ico">
    <link rel="stylesheet" href="{THEME_ASSETS_PATH}/css/jquery-ui-{THEME_COLOR}.css?v={THEME_ASSETS_VERSION}">
    <link rel="stylesheet" href="{THEME_ASSETS_PATH}/css/ui.css?v={THEME_ASSETS_VERSION}">
    <link rel="stylesheet" href="{THEME_ASSETS_PATH}/css/multi-select.css?v={THEME_ASSETS_VERSION}">
    <link rel="stylesheet" href="{THEME_ASSETS_PATH}/css/{THEME_COLOR}.css?v={THEME_ASSETS_VERSION}">
    <script>
        imscp_i18n = {JS_TRANSLATIONS};
    </script>
    <script src="{THEME_ASSETS_PATH}/js/jquery/jquery.js?v={THEME_ASSETS_VERSION}"></script>
    <script src="{THEME_ASSETS_PATH}/js/jquery/jquery-ui.js?v={THEME_ASSETS_VERSION}"></script>
    <script src="{THEME_ASSETS_PATH}/js/jquery/plugins/dataTables.js?v={THEME_ASSETS_VERSION}"></script>
    <script src="{THEME_ASSETS_PATH}/js/jquery/plugins/dataTables_naturalSorting.js?v={THEME_ASSETS_VERSION}"></script>
    <script src="{THEME_ASSETS_PATH}/js/jquery/plugins/pGenerator.js?v={THEME_ASSETS_VERSION}"></script>
    <script src="{THEME_ASSETS_PATH}/js/jquery/plugins/jquery.multi-select.js?v={THEME_ASSETS_VERSION}"></script>
    <script src="{THEME_ASSETS_PATH}/js/imscp.min.js?v={THEME_ASSETS_VERSION}"></script>
</head>
<body>
<div id="wrapper">
    <div class="header">
        <!-- INCLUDE shared/partials/navigation/main_menu.tpl -->
        <div class="logo"><img src="{ISP_LOGO}" alt="i-MSCP logo"/></div>
    </div>
    <div class="location">
        <div class="location-area">
            <h1 class="{SECTION_TITLE_CLASS}">{TR_SECTION_TITLE}</h1>
        </div>
        <ul class="location-menu">
            <!-- BDP: signed_in -->
            <li><span>{YOU_ARE_SIGNED_IN_AS}</span></li>
            <!-- EDP: signed_in -->
            <!-- BDP: signed_in_from -->
            <li><a class="su_back" href="su.php" title="{TR_SIGN_IN_BACK_TOOLTIP}">{YOU_ARE_SIGNED_IN_AS}</a></li>
            <!-- EDP: signed_in_from -->
            <li><a class="logout" href="/index.php?signout=1" title="{TR_SIGN_OUT_TOOLTIP}">{TR_SIGN_OUT}</a></li>
        </ul>
        <!-- INCLUDE shared/partials/navigation/breadcrumbs.tpl -->
    </div>
    <!-- INCLUDE shared/partials/navigation/left_menu.tpl -->
    <div class="body">
        <h2 class="{TITLE_CLASS}"><span>{TR_TITLE}</span></h2>
        <!-- BDP: page_message -->
        <div class="{MESSAGE_CLS}">{MESSAGE}</div>
        <!-- EDP: page_message -->
        {LAYOUT_CONTENT}
    </div>
</div>
<div class="footer">
    i-MSCP {VERSION}<br>
    Build: {BUILDDATE}<br>
    Codename: {CODENAME}
</div>
</body>
</html>
