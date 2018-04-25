<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

use iMSCP\Application;
use iMSCP\Events;
use iMSCP\i18n\GettextParser;
use iMSCP\Utility\OpcodeCache;

/**
 * Translates the given string
 *
 * @param string $messageId Translation string
 * @param string ...$params OPTIONAL Parameters
 * @return string
 */
function tr(string $messageId, string ...$params): string
{
    return empty($params)
        ? Application::getInstance()->getTranslator()->translate($messageId)
        : vsprintf(Application::getInstance()->getTranslator()->translate($messageId), $params);
}

/**
 * Translates the given string using plural notations
 *
 * @param string $singular Singular translation string
 * @param string $plural Plural translation string
 * @param integer $number Number for detecting the correct plural
 * @param string ...$params
 * @return string
 */
function ntr(string $singular, string $plural, int $number, string ...$params): string
{
    return empty($params)
        ? Application::getInstance()->getTranslator()->translatePlural($singular, $plural, $number)
        : vsprintf(Application::getInstance()->getTranslator()->translatePlural($singular, $plural, $number), $params);
}

/**
 * Build languages index from machine object files
 *
 * @return void
 */
function buildLanguagesIndex(): void
{
    $cfg = Application::getInstance()->getConfig();

    // Clear translation cache
    $translator = Application::getInstance()->getTranslator();

    /** @var \Zend\Cache\Storage\Adapter\Apcu $cache */
    if ($cache = $translator->getCache()) {
        $cache->clearByNamespace('Zend_I18n_Translator_Messages');
    }

    # Clear opcode cache if any
    OpcodeCache::clearAllActive();

    $iterator = new \RecursiveIteratorIterator(
        new \RecursiveDirectoryIterator($cfg['FRONTEND_ROOT_DIR'] . '/i18n/locales/', \FilesystemIterator::SKIP_DOTS)
    );

    $availableLanguages = [];

    /** @var $item \SplFileInfo */
    foreach ($iterator as $item) {
        if (!$item->isReadable()) {
            continue;
        }

        $basename = $item->getBasename();
        $parser = new GettextParser($item->getPathname());
        $translationTable = $parser->getTranslationTable();

        if (!empty($translationTable)) {
            $poCreationDate = \DateTime::createFromFormat('Y-m-d H:i O', $parser->getPotCreationDate());
            $availableLanguages[$basename] = [
                'locale'            => $parser->getLanguage(),
                'creation'          => $poCreationDate->format('Y-m-d H:i'),
                'translatedStrings' => $parser->getNumberOfTranslatedStrings(),
                'lastTranslator'    => $parser->getLastTranslator()
            ];

            if (isset($translationTable['_: Localised language'])) {
                $availableLanguages[$basename]['language'] = $translationTable['_: Localised language'];
            } else {
                $availableLanguages[$basename]['language'] = tr('Unknown');
            }

            continue;
        }

        if (PHP_SAPI != 'cli') {
            setPageMessage(tr('The %s translation file has been ignored: Translation table is empty.', $basename), 'warning');
        }
    }

    $dbConfig = Application::getInstance()->getDbConfig();
    sort($availableLanguages);
    $serializedData = serialize($availableLanguages);
    $dbConfig['AVAILABLE_LANGUAGES'] = $serializedData;
    $cfg['AVAILABLE_LANGUAGES'] = $serializedData;
}

/**
 * Returns list of available languages
 *
 * @param bool $localesOnly Flag indicating whether or not only list of locales must be returned
 * @return array Array that contains information about available languages
 */
function getAvailableLanguages(bool $localesOnly = false): array
{
    $cfg = Application::getInstance()->getConfig();

    if (!isset($cfg['AVAILABLE_LANGUAGES']) || !isSerialized($cfg['AVAILABLE_LANGUAGES'])) {
        buildLanguagesIndex();
    }

    $languages = unserialize($cfg['AVAILABLE_LANGUAGES']);

    if ($localesOnly) {
        $locales = [\Locale::getDefault()];

        foreach ($languages as $language) {
            $locales[] = $language['locale'];
        }

        return $locales;
    }

    array_unshift($languages, [
        'locale'            => \Locale::getDefault(),
        'creation'          => tr('N/A'),
        'translatedStrings' => tr('N/A'),
        'lastTranslator'    => tr('N/A'),
        'language'          => tr('Auto (Browser language)')
    ]);

    return $languages;
}

/**
 * Import Machine object file in languages directory
 *
 * @return bool TRUE on success, FALSE otherwise
 */
function importMachineObjectFile(): bool
{
    // closure that is run before move_uploaded_file() function - See the Utils_UploadFile() function for further
    // information about implementation details
    $beforeMove = function () {
        $localesDirectory = Application::getInstance()->getConfig()['FRONTEND_ROOT_DIR'] . '/i18n/locales';
        $filePath = $_FILES['languageFile']['tmp_name'];

        if (!is_readable($filePath)) {
            setPageMessage(tr('File is not readable.'), 'error');
            return false;
        }

        try {
            $parser = new GettextParser($filePath);
            $encoding = $parser->getContentType();
            $locale = $parser->getLanguage();
            $creation = $parser->getPotCreationDate();
            $translationTable = $parser->getTranslationTable();
        } catch (\Exception $e) {
            setPageMessage(tr('Only gettext Machine Object files (MO files) are accepted.'), 'error');
            return false;
        }

        $language = isset($translationTable['_: Localised language']) ? $translationTable['_: Localised language'] : '';

        if (empty($encoding) || empty($locale) || empty($creation) || empty($lastTranslator) || empty($language)) {
            setPageMessage(tr("%s is not a valid i-MSCP language file.", toHtml($_FILES['languageFile']['name'])), 'error');
            return false;
        }

        if (!is_dir("$localesDirectory/$locale")) {
            if (!@mkdir("$localesDirectory/$locale", 0700)) {
                setPageMessage(tr("Unable to create '%s' directory for language file.", toHtml($locale)), 'error');
                return false;
            }
        }

        if (!is_dir("$localesDirectory/$locale/LC_MESSAGES")) {
            if (!@mkdir("$localesDirectory/$locale/LC_MESSAGES", 0700)) {
                setPageMessage(tr("Unable to create 'LC_MESSAGES' directory for language file."), 'error');
                return false;
            }
        }

        // Return destination file path
        return "$localesDirectory/$locale/LC_MESSAGES/$locale.mo";
    };

    if (uploadFile('languageFile', [$beforeMove]) === false) {
        return false;
    }

    // Rebuild language index
    buildLanguagesIndex();
    return true;
}

/**
 * Change panel default language
 *
 * @return bool TRUE if language name is valid, FALSE otherwise
 */
function changeDefaultLanguage(): bool
{
    if (!isset($_POST['defaultLanguage'])) {
        return false;
    }

    $defaultLanguage = cleanInput($_POST['defaultLanguage']);
    $availableLanguages = getAvailableLanguages();

    // Check for language availability
    $isValidLanguage = false;
    foreach ($availableLanguages as $languageDefinition) {
        if ($languageDefinition['locale'] == $defaultLanguage) {
            $isValidLanguage = true;
        }
    }

    if (!$isValidLanguage) {
        return false;
    }

    $dbConfig = Application::getInstance()->getDbConfig();
    $dbConfig['USER_INITIAL_LANG'] = $defaultLanguage;
    Application::getInstance()->getConfig()['USER_INITIAL_LANG'] = $defaultLanguage;

    // Ensures language change on next load for current user in case he has not yet his frontend properties explicitly
    // set (eg. for the first admin user when i-MSCP was just installed
    $session = Application::getInstance()->getSession();
    $stmt = execQuery('SELECT lang FROM user_gui_props WHERE user_id = ?', [$session['user_id']]);
    if ($stmt->fetchColumn() == NULL) {
        unset($session['user_def_lang']);
    }

    return true;
}

/**
 * Get JS translations strings
 *
 * Note: Plugins can register their own JS translation strings by listening on
 * the onGetJsTranslations event, and add them to the translations ArrayObject
 * which is a parameter of that event.
 *
 * For instance:
 *
 * use iMSCP_Events as Events;
 * use iMSCP_Events_Event as Event;
 *
 * Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function(Event $e) {
 *    $e->getParam('translations')->my_namespace = array(
 *        'first_translation_string_identifier' => tr('my first translation string'),
 *        'second_translation_string_identifier' => tr('my second translation string')
 *    );
 * });
 *
 * Then, in your JS script, you can access your translation strings as follow:
 *
 * imscp_i18n.my_namespace.first_translation_string_identifier
 * imscp_i18n.my_namespace.second_translation_string_identifier
 * ...
 *
 * @return string JS object as string
 */
function getJsTranslations(): string
{
    $translations = new \ArrayObject([
        // Core translation strings
        'core' => [
            'ok'                      => tr('Ok'),
            'warning'                 => tr('Warning!'),
            'yes'                     => tr('Yes'),
            'no'                      => tr('No'),
            'confirmation_required'   => tr('Confirmation required'),
            'close'                   => tr('Close'),
            'generate'                => tr('Generate'),
            'show'                    => tr('Show'),
            'your_new_password'       => tr('Your new password'),
            'password_generate_alert' => tr('You must first generate a password by clicking on the generate button.'),
            'password_length'         => Application::getInstance()->getConfig()['PASSWD_CHARS']
        ]],
        \ArrayObject::ARRAY_AS_PROPS
    );

    Application::getInstance()->getEventManager()->trigger(Events::onGetJsTranslations, NULL, ['translations' => $translations]);
    return json_encode($translations, JSON_FORCE_OBJECT);
}
