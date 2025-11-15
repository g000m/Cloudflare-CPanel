<?php

namespace CF\Cpanel;

use CF\API\APIInterface;
use CF\API\Request;
use CF\Integration\DefaultIntegration;

class TokenActions
{
    private $api;
    private $config;
    private $cpanelAPI;
    private $dataStore;
    private $logger;
    private $request;

    /**
     * @param DefaultIntegration $cpanelIntegration
     * @param APIInterface       $api
     * @param Request            $request
     */
    public function __construct(DefaultIntegration $cpanelIntegration, APIInterface $api, Request $request)
    {
        $this->api = $api;
        $this->config = $cpanelIntegration->getConfig();
        $this->cpanelAPI = $cpanelIntegration->getIntegrationAPI();
        $this->dataStore = $cpanelIntegration->getDataStore();
        $this->logger = $cpanelIntegration->getLogger();
        $this->request = $request;
    }

    /**
     * Verify and save API token
     * POST /user/tokens/verify
     *
     * @return array
     */
    public function verifyAndSaveToken()
    {
        $bodyParameters = $this->request->getBody();

        if (!isset($bodyParameters['api_token'])) {
            return $this->api->createAPIError("Missing parameter 'api_token'.");
        }

        $apiToken = $bodyParameters['api_token'];

        // Step 1: Verify the token
        $verifyRequest = new Request('GET', 'user/tokens/verify', array(), array());
        // Temporarily set the token in headers for verification
        $verifyRequest->setHeaders(array(
            'Authorization' => 'Bearer ' . $apiToken,
            'Content-Type' => 'application/json',
        ));

        try {
            $verifyResponse = $this->api->getHttpClient()->send($verifyRequest);

            if (!isset($verifyResponse['success']) || !$verifyResponse['success']) {
                $errorMessage = 'Invalid API token';
                if (isset($verifyResponse['errors'][0]['message'])) {
                    $errorMessage = $verifyResponse['errors'][0]['message'];
                }
                return $this->api->createAPIError($errorMessage);
            }
        } catch (\Exception $e) {
            return $this->api->createAPIError('Failed to verify API token: ' . $e->getMessage());
        }

        // Step 2: Get user details to retrieve email
        $userRequest = new Request('GET', 'user', array(), array());
        $userRequest->setHeaders(array(
            'Authorization' => 'Bearer ' . $apiToken,
            'Content-Type' => 'application/json',
        ));

        try {
            $userResponse = $this->api->getHttpClient()->send($userRequest);

            if (!isset($userResponse['success']) || !$userResponse['success']) {
                return $this->api->createAPIError('Failed to retrieve user details');
            }

            $email = $userResponse['result']['email'];

            // Step 3: Save token and email to DataStore
            $this->dataStore->createUserDataStore($apiToken, $email);

            return array(
                'result' => array(
                    'email' => $email,
                    'status' => 'verified',
                ),
                'success' => true,
                'errors' => array(),
                'messages' => array('API token verified and saved successfully'),
            );
        } catch (\Exception $e) {
            return $this->api->createAPIError('Failed to retrieve user details: ' . $e->getMessage());
        }
    }

    /**
     * Get current user details using stored token
     * GET /user
     *
     * @return array
     */
    public function getUserDetails()
    {
        $userRequest = new Request('GET', 'user', array(), array());

        return $this->api->callAPI($userRequest);
    }

    /**
     * Verify current stored token is still valid
     * GET /user/tokens/verify
     *
     * @return array
     */
    public function verifyStoredToken()
    {
        $verifyRequest = new Request('GET', 'user/tokens/verify', array(), array());

        return $this->api->callAPI($verifyRequest);
    }
}
