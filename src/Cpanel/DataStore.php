<?php

namespace CF\Cpanel;

use CF\Integration\DefaultLogger;
use Symfony\Component\Yaml\Yaml as Yaml;
use CF\Integration\DataStoreInterface;

class DataStore implements DataStoreInterface
{
    private $cpanel;
    private $username;
    private $homeDir;
    private $yamlData;

    const PATH_TO_YAML_FILE = '/.cpanel/datastore';
    const YAML_FILE_NAME = 'cloudflare_data.yaml';

    const API_TOKEN_KEY = 'api_token';
    const EMAIL_KEY = 'cloudflare_email';

    // Deprecated keys - no longer used in v8.0+ (token-based auth)
    // const CLIENT_API_KEY = 'client_api_key';
    // const HOST_USER_UNIQUE_ID_KEY = 'host_user_unique_id';
    // const HOST_USER_KEY = 'host_user_key';
    // const DEPRECATED_HOST_USER_UNIQUE_ID_KEY = 'cf_user_tokens';

    /**
     * @param CpanelAPI     $cpanel
     * @param DefaultLogger $logger
     */
    public function __construct(CpanelAPI $cpanel, DefaultLogger $logger)
    {
        $this->cpanel = $cpanel;
        $this->logger = $logger;
        $this->username = $this->cpanel->getUserId();
        $this->homeDir = $this->cpanel->getHomeDir();
        $this->yamlData = $this->loadYAMLFile();
    }

    /**
     * @return array
     */
    private function loadYAMLFile()
    {
        $getFileContent = $this->cpanel->loadFile($this->homeDir.self::PATH_TO_YAML_FILE, self::YAML_FILE_NAME);
        if ($this->cpanel->uapiResponseOk($getFileContent)) {
            return Yaml::parse($getFileContent['content']);
        } else {
            $this->logger->error(self::PATH_TO_YAML_FILE.self::YAML_FILE_NAME.' does not exist.');
        }

        return false;
    }

    /**
     * @return bool
     */
    private function saveYAMLFile()
    {
        $fileContents = Yaml::dump($this->yamlData);
        $result = $this->cpanel->saveFile($this->homeDir.self::PATH_TO_YAML_FILE, self::YAML_FILE_NAME, $fileContents);

        return $this->cpanel->uapiResponseOk($result);
    }

    /**
     * @param $apiToken
     * @param $email
     */
    public function createUserDataStore($apiToken, $email)
    {
        $this->yamlData = array(
            self::API_TOKEN_KEY => $apiToken,
            self::EMAIL_KEY => $email,
        );

        $this->saveYAMLFile();
    }

    /**
     * @return API token for current user
     */
    public function getAPIToken()
    {
        return $this->get(self::API_TOKEN_KEY);
    }

    /**
     * @return cloudflare email
     */
    public function getCloudFlareEmail()
    {
        return $this->get(self::EMAIL_KEY);
    }

    // Legacy methods - kept for backwards compatibility but deprecated
    // These will return null for new token-based installations

    /**
     * @deprecated Use getAPIToken() instead
     * @return null
     */
    public function getClientV4APIKey()
    {
        // For backwards compatibility with old code that may still call this
        return null;
    }

    /**
     * @deprecated No longer used in token-based authentication
     * @return null
     */
    public function getHostAPIUserUniqueId()
    {
        return null;
    }

    /**
     * @deprecated No longer used in token-based authentication
     * @return null
     */
    public function getHostAPIUserKey()
    {
        return null;
    }

    /**
     * @param $key
     *
     * @return mixed
     */
    public function get($key)
    {
        return $this->yamlData[$key];
    }

    /**
     * @param $key
     * @param $value
     *
     * @return mixed
     */
    public function set($key, $value)
    {
        if (isEmpty($this->yamlData)) {
            $this->yamlData = array();
        }

        $this->yamlData[$key] = $value;

        return $this->saveYAMLFile();
    }
}
