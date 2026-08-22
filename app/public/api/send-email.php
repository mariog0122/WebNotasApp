<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    echo json_encode(['status' => 'ok']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

if (!$input || empty($input['to']) || empty($input['subject']) || empty($input['html'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Faltan campos obligatorios.']);
    exit;
}

$authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
$secretKey = 'Bearer LOGREVA_MAILER_SECRET_2026';

if ($authHeader !== $secretKey) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Acceso no autorizado al servicio de correo.']);
    exit;
}

$to = filter_var($input['to'], FILTER_VALIDATE_EMAIL);
if (!$to) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Dirección de correo no válida.']);
    exit;
}

$domain = 'adyronweb.site';
$fromEmail = 'notificaciones@' . $domain;
$fromName = 'LOGREVA Notificaciones';

$subject = '=?UTF-8?B?' . base64_encode($input['subject']) . '?=';

$body = "<!DOCTYPE html>\n<html lang=\"es\">\n<head><meta charset=\"UTF-8\"></head>\n<body style=\"font-family: Arial, Helvetica, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px;\">\n";
$body .= $input['html'];
$body .= "\n</body>\n</html>";

$domainMsgId = time() . '.' . md5($to . $subject) . '@' . $domain;

$headers = array(
    'MIME-Version: 1.0',
    'Content-Type: text/html; charset=UTF-8',
    'Content-Transfer-Encoding: 8bit',
    'From: ' . $fromName . ' <' . $fromEmail . '>',
    'Reply-To: soporte@' . $domain,
    'Return-Path: <' . $fromEmail . '>',
    'Message-ID: <' . $domainMsgId . '>',
    'X-Mailer: LOGREVA Mailer 1.0',
    'X-Priority: 3 (Normal)',
    'Auto-Submitted: auto-generated'
);

$mailSent = @mail($to, $subject, $body, implode("\r\n", $headers), '-f' . $fromEmail);

if ($mailSent) {
    echo json_encode(['success' => true, 'message' => 'Correo enviado exitosamente.']);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error enviando correo desde el servidor de Hostinger.']);
}
