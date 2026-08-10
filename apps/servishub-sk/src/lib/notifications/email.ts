/**
 * Notification layer — email via Resend.
 * Stub behavior: without RESEND_API_KEY the email is logged and skipped, so
 * booking flows work end-to-end before the email provider is wired (T0 infra).
 */

import { formatZonedDate, formatZonedTime } from "@/lib/booking/slots";
import { formatEur } from "@/lib/format";

const RESEND_ENDPOINT = "https://api.resend.com/emails";

type EmailMessage = {
  to: string;
  subject: string;
  text: string;
};

export type SendEmailResult = {
  delivered: boolean;
  reason?: "missing_api_key" | "provider_error";
};

export async function sendEmail(message: EmailMessage): Promise<SendEmailResult> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.info("[notifications] RESEND_API_KEY not set — email skipped:", {
      to: message.to,
      subject: message.subject,
    });
    return { delivered: false, reason: "missing_api_key" };
  }

  try {
    const response = await fetch(RESEND_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from:
          process.env.RESEND_FROM ?? "ServisHub SK <noreply@servishub.sk>",
        to: message.to,
        subject: message.subject,
        text: message.text,
      }),
    });

    if (!response.ok) {
      console.error(
        "[notifications] Resend rejected email:",
        response.status,
        await response.text(),
      );
      return { delivered: false, reason: "provider_error" };
    }
    return { delivered: true };
  } catch (error) {
    console.error("[notifications] email send failed:", error);
    return { delivered: false, reason: "provider_error" };
  }
}

export type BookingConfirmationParams = {
  to: string;
  customerName?: string | null;
  providerName: string;
  serviceTitle: string;
  start: Date;
  durationMin: number;
  priceAmount?: number | null;
};

/** Booking confirmation (PENDING) email to the customer. */
export async function sendBookingConfirmationEmail(
  params: BookingConfirmationParams,
): Promise<SendEmailResult> {
  const date = formatZonedDate(params.start);
  const time = formatZonedTime(params.start);
  const end = new Date(params.start.getTime() + params.durationMin * 60000);
  const timeRange = `${time} – ${formatZonedTime(end)}`;
  const price =
    params.priceAmount !== null && params.priceAmount !== undefined
      ? `\nOrientačná cena: ${formatEur(params.priceAmount)}`
      : "";

  const greeting = params.customerName
    ? `Dobrý deň, ${params.customerName},`
    : "Dobrý deň,";

  return sendEmail({
    to: params.to,
    subject: `Rezervácia prijatá: ${params.serviceTitle} (${date} ${time})`,
    text: [
      greeting,
      "",
      "vaša rezervácia bola prijatá a čaká na potvrdenie profesionálom.",
      "",
      `Profesionál: ${params.providerName}`,
      `Služba: ${params.serviceTitle}`,
      `Termín: ${date}, ${timeRange}`,
      price,
      "",
      "Stav rezervácie a prípadné zrušenie nájdete na stránke Moje rezervácie.",
      "",
      "ServisHub SK",
    ]
      .filter(Boolean)
      .join("\n"),
  });
}
