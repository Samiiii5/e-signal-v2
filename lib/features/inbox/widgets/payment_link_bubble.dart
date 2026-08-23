import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/mock/messages_mock.dart';

/// Bulle de conversation affichant un lien de paiement.
///
/// Deux sources de données, dans cet ordre de priorité :
/// 1. [Message.paymentLink] — objet typé issu de l'API
/// 2. les champs plats `paymentAmount` / `paymentCurrency` / `paymentStatus`,
///    renseignés lors d'une création locale (feuille de paiement, mock)
class PaymentLinkBubble extends StatelessWidget {
  final Message message;

  const PaymentLinkBubble({super.key, required this.message});

  /// Construit un modèle exploitable quelle que soit la provenance du message.
  PaymentLinkModel get _link {
    final fromApi = message.paymentLink;
    if (fromApi != null) return fromApi;
    return PaymentLinkModel(
      description: message.content,
      amount: double.tryParse(message.paymentAmount ?? '') ?? 0.0,
      currency: message.paymentCurrency ?? 'XOF',
      status: switch (message.paymentStatus) {
        PaymentStatus.paid => 'paid',
        PaymentStatus.pending => 'pending',
        PaymentStatus.created => 'created',
        PaymentStatus.expired => 'expired',
        null => '',
      },
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppSnackbar.error('Lien de paiement invalide'));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(
        AppSnackbar.error('Impossible d\'ouvrir le lien de paiement'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    final fromContact = message.isFromContact;
    // Bouton actif seulement si une URL exploitable existe et que le paiement
    // n'est pas déjà réglé.
    final canPay = link.hasUrl && !link.isPaid;

    return Align(
      alignment: fromContact ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.greenLight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête : libellé + badge de statut ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 14, color: AppColors.greenDark),
                  const SizedBox(width: 6),
                  const Text(
                    'Lien de paiement',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.greenDark,
                    ),
                  ),
                  const Spacer(),
                  if (link.status.isNotEmpty) _StatusBadge(status: link.status),
                ],
              ),
            ),

            // ── Titre du produit ──
            if (link.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Text(
                  link.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // ── Montant ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                link.description.isNotEmpty ? 6 : 12,
                14,
                12,
              ),
              child: Text(
                '${link.formattedAmount} ${link.currency}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            // ── Bouton ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canPay
                      ? () => _openLink(context, link.url!)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.borderLight,
                    disabledForegroundColor: AppColors.textHint,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                  child: Text(
                    link.isPaid ? 'Déjà payé' : 'Payer maintenant',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge de statut ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status.toLowerCase()) {
      'paid' ||
      'completed' ||
      'success' => (AppColors.statusPaidBg, AppColors.statusPaidText, 'Payé'),
      'pending' || 'processing' => (
        AppColors.statusPendingBg,
        AppColors.statusPendingText,
        'En attente',
      ),
      'expired' || 'cancelled' || 'canceled' => (
        AppColors.statusExpiredBg,
        AppColors.statusExpiredText,
        'Expiré',
      ),
      _ => (AppColors.statusCreatedBg, AppColors.statusCreatedText, 'Créé'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
