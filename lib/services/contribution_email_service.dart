import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../config/auth_config.dart';

/// Direct, resilient email delivery service for contributions.
/// Uses Gmail SMTP credentials synchronized from Supabase / AuthConfig.
class ContributionEmailService {
  ContributionEmailService._();

  static final ContributionEmailService instance = ContributionEmailService._();

  /// Sends a confirmation email to the donor and an alert to admin@allo-halal.com
  Future<void> sendContributionEmails({
    String? donorEmail,
    String? donorName,
    required double amount,
    String? currency,
    String? tier,
    String? transactionId,
    String? paymentMethod,
  }) async {
    final host = AuthConfig.smtpHost;
    final port = AuthConfig.smtpPort;
    final user = AuthConfig.smtpUser.trim();
    final pass = AuthConfig.smtpPass.trim().replaceAll(' ', '');
    final fromEmail = AuthConfig.smtpFromEmail.trim().isNotEmpty
        ? AuthConfig.smtpFromEmail.trim()
        : user;
    final fromName = AuthConfig.smtpFromName.trim().isNotEmpty
        ? AuthConfig.smtpFromName.trim()
        : 'Allo Halal';

    if (user.isEmpty || pass.isEmpty) {
      if (kDebugMode) {
        debugPrint('[ContributionEmailService] SMTP user or pass is empty. Skipping email.');
      }
      return;
    }

    final effectiveCurrency = (currency ?? 'EUR').toUpperCase();
    final symbol = effectiveCurrency == 'EUR'
        ? '€'
        : effectiveCurrency == 'USD'
            ? '\$'
            : effectiveCurrency;
    final formattedAmount = '${amount.toStringAsFixed(2)} $symbol';
    final effectiveDonorName = (donorName != null && donorName.trim().isNotEmpty)
        ? donorName.trim()
        : 'Généreux Donateur';
    final effectiveMethod = (paymentMethod ?? 'Stripe').toUpperCase();
    final effectiveTier = (tier ?? 'SERVER').toUpperCase();
    final effectiveTxnId = transactionId ?? 'tx_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} à ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final smtpServer = SmtpServer(
      host,
      port: port,
      username: user,
      password: pass,
      ssl: false,
      allowInsecure: true,
    );

    // 1. Send Donor Confirmation Email
    if (donorEmail != null && donorEmail.trim().contains('@')) {
      final cleanDonorEmail = donorEmail.trim();
      final donorMessage = Message()
        ..from = Address(fromEmail, fromName)
        ..recipients.add(cleanDonorEmail)
        ..subject = 'BarakAllahu Fik pour votre don de $formattedAmount à Allo Halal 💚'
        ..html = '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <title>Merci pour votre contribution</title>
</head>
<body style="margin:0;padding:20px;background-color:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#1e293b;">
  <div style="max-width:540px;margin:0 auto;background:#ffffff;border-radius:20px;border:1px solid #e2e8f0;overflow:hidden;box-shadow:0 4px 15px rgba(0,0,0,0.04);">
    <div style="background:linear-gradient(135deg,#088839 0%,#059669 100%);padding:36px 30px;text-align:center;">
      <div style="font-size:42px;margin-bottom:10px;">🤲</div>
      <h1 style="margin:0 0 6px 0;font-size:24px;font-weight:800;color:#ffffff;">BarakAllahu Fik !</h1>
      <p style="margin:0;font-size:14px;color:#d1fae5;font-weight:500;">Votre soutien donne vie à la communauté Allo Halal</p>
    </div>
    <div style="padding:32px 30px;">
      <p style="font-size:15px;line-height:1.6;margin:0 0 18px 0;color:#334155;">
        Cher(e) <strong>$effectiveDonorName</strong>,
      </p>
      <p style="font-size:14px;line-height:1.6;margin:0 0 22px 0;color:#475569;">
        Nous confirmons la bonne réception de votre contribution libre. Grâce à votre générosité, nous pouvons continuer à proposer un service d'analyse Halal 100% indépendant, gratuit et sans abonnement obligatoire.
      </p>
      <div style="background-color:#f0fdf4;border:1px solid #bbf7d0;border-radius:14px;padding:16px 20px;margin-bottom:22px;">
        <div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px dashed #bbf7d0;">
          <span style="font-size:13px;color:#166534;font-weight:600;">Montant :</span>
          <span style="font-size:17px;color:#088839;font-weight:800;">$formattedAmount</span>
        </div>
        <div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px dashed #bbf7d0;">
          <span style="font-size:13px;color:#166534;">Mode de paiement :</span>
          <span style="font-size:13px;color:#15803d;font-weight:600;">$effectiveMethod</span>
        </div>
        <div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px dashed #bbf7d0;">
          <span style="font-size:13px;color:#166534;">Palier :</span>
          <span style="font-size:13px;color:#15803d;font-weight:600;">$effectiveTier</span>
        </div>
        <div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px dashed #bbf7d0;">
          <span style="font-size:13px;color:#166534;">Date :</span>
          <span style="font-size:12px;color:#64748b;">$dateStr</span>
        </div>
        <div style="display:flex;justify-content:space-between;padding:6px 0;">
          <span style="font-size:13px;color:#166534;">Référence :</span>
          <span style="font-size:11px;color:#64748b;font-family:monospace;">$effectiveTxnId</span>
        </div>
      </div>
      <div style="background-color:#f8fafc;border-left:4px solid #088839;border-radius:6px;padding:12px 16px;margin-bottom:22px;">
        <span style="font-size:12px;color:#475569;line-height:1.5;">
          🌱 <strong>Engagement solidaire :</strong> Une part de chaque contribution est reversée à des œuvres caritatives vérifiées pour l'aide alimentaire d'urgence.
        </span>
      </div>
      <p style="font-size:13px;color:#64748b;line-height:1.5;margin:0;">
        Qu'Allah accepte votre don et bénisse vos actions.<br>
        L'équipe <strong>Allo Halal</strong>
      </p>
    </div>
    <div style="background-color:#f1f5f9;padding:16px 20px;text-align:center;border-top:1px solid #e2e8f0;">
      <p style="margin:0;font-size:11px;color:#94a3b8;">
        © ${now.year} Allo Halal — Modèle à Prix Libre & Éthique.
      </p>
    </div>
  </div>
</body>
</html>
''';

      try {
        await send(donorMessage, smtpServer);
        if (kDebugMode) debugPrint('[ContributionEmailService] Donor email sent to $cleanDonorEmail');
      } catch (e) {
        if (kDebugMode) debugPrint('[ContributionEmailService] Donor email error: $e');
      }
    }

    // 2. Send Admin Alert Email (admin@allo-halal.com)
    const adminEmail = 'admin@allo-halal.com';
    final adminMessage = Message()
      ..from = Address(fromEmail, fromName)
      ..recipients.add(adminEmail)
      ..subject = '🚨 [Nouveau Don] $formattedAmount reçu de $effectiveDonorName ($effectiveMethod)'
      ..html = '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <title>Alerte Don</title>
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background-color:#f8fafc;padding:20px;margin:0;color:#1e293b;">
  <div style="max-width:500px;margin:0 auto;background:#ffffff;border:1px solid #e2e8f0;border-radius:16px;padding:24px;box-shadow:0 4px 12px rgba(0,0,0,0.03);">
    <h2 style="margin:0 0 4px 0;font-size:18px;color:#088839;">💰 Nouvelle Contribution Enregistrée !</h2>
    <p style="margin:0 0 16px 0;font-size:12px;color:#64748b;">Allo Halal Admin Alert System</p>
    <div style="background:#f8fafc;border-radius:12px;padding:14px;border:1px solid #e2e8f0;margin-bottom:20px;font-size:13px;line-height:1.8;">
      <div><strong>Montant :</strong> <span style="font-size:16px;color:#088839;font-weight:800;">$formattedAmount</span></div>
      <div><strong>Passerelle :</strong> $effectiveMethod</div>
      <div><strong>Palier :</strong> $effectiveTier</div>
      <div><strong>Donateur :</strong> $effectiveDonorName</div>
      <div><strong>Email :</strong> ${donorEmail ?? 'Non renseigné'}</div>
      <div><strong>ID Transaction :</strong> <span style="font-family:monospace;font-size:11px;color:#64748b;">$effectiveTxnId</span></div>
      <div><strong>Date :</strong> $dateStr</div>
    </div>
    <p style="margin:0;font-size:12px;color:#94a3b8;text-align:center;">
      Transaction synchronisée en direct avec Supabase & SMTP.
    </p>
  </div>
</body>
</html>
''';

    try {
      await send(adminMessage, smtpServer);
      if (kDebugMode) debugPrint('[ContributionEmailService] Admin alert sent to $adminEmail');
    } catch (e) {
      if (kDebugMode) debugPrint('[ContributionEmailService] Admin alert error: $e');
    }
  }
}

