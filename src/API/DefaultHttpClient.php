<?php

namespace CF\API;

use CF\API\Request;
use GuzzleHttp;
use GuzzleHttp\Exception\RequestException;
use GuzzleHttp\Psr7\Request as Psr7Request;

class DefaultHttpClient implements HttpClientInterface
{
    const CONTENT_TYPE_KEY = 'Content-Type';
    const APPLICATION_JSON_KEY = 'application/json';

    protected $client;

    /**
     * @param String $endpoint
     */
    public function __construct($endpoint)
    {
        $this->client = new GuzzleHttp\Client(['base_uri' => $endpoint]);
    }

    /**
     * @param  Request $request
     * @throws RequestException
     * @return Array $response
     */
    public function send(Request $request)
    {
        $apiRequest = $this->createGuzzleRequest($request);

        $response = $this->client->send($apiRequest);
        $responseBody = json_decode($response->getBody()->getContents(), true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new RequestException('Error decoding client API JSON', $apiRequest);
        }

        return $responseBody;
    }

    /**
     * @param  Request $request
     * @return Psr7Request
     */
    public function createGuzzleRequest(Request $request)
    {
        $bodyType = (($request->getHeaders()[self::CONTENT_TYPE_KEY] === self::APPLICATION_JSON_KEY) ? 'json' : 'body');

        $requestOptions = array(
            'headers' => $request->getHeaders(),
            'query' => $request->getParameters(),
            $bodyType => $request->getBody(),
        );

        // For Guzzle 7.x, we use request() method with options instead of createRequest()
        // We'll create a PSR-7 request for compatibility
        $body = null;
        if ($bodyType === 'json') {
            $body = json_encode($request->getBody());
            $requestOptions['headers'][self::CONTENT_TYPE_KEY] = self::APPLICATION_JSON_KEY;
        } elseif (!empty($request->getBody())) {
            $body = http_build_query($request->getBody());
        }

        return new Psr7Request(
            $request->getMethod(),
            $request->getUrl(),
            $requestOptions['headers'],
            $body
        );
    }

    /**
     * @param GuzzleHttpClient $client
     */
    public function setClient($client)
    {
        $this->client = $client;
    }
}
