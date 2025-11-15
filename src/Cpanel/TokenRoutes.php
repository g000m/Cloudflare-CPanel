<?php

namespace CF\Cpanel;

class TokenRoutes
{
    /**
     * Token-based authentication routes for API v4
     */
    public static $routes = array(
        'token_verify' => array(
            'class' => 'CF\Cpanel\TokenActions',
            'methods' => array(
                'POST' => array(
                    'function' => 'verifyAndSaveToken'
                )
            )
        ),
        'user_details' => array(
            'class' => 'CF\Cpanel\TokenActions',
            'methods' => array(
                'GET' => array(
                    'function' => 'getUserDetails'
                )
            )
        ),
        'token_status' => array(
            'class' => 'CF\Cpanel\TokenActions',
            'methods' => array(
                'GET' => array(
                    'function' => 'verifyStoredToken'
                )
            )
        ),
    );
}
