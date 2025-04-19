import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import Stripe from "stripe";
import {defineSecret} from "firebase-functions/params";

admin.initializeApp();

// ✅ Secret definition
const stripeSecret = defineSecret("STRIPE_SECRET");

interface PaymentIntentData {
  amount: number;
  currency: string;
}

export const createPaymentIntent = onRequest(
  {
    secrets: [stripeSecret],
    region: "us-central1", // Optional: specify region
  },
  async (req, res): Promise<void> => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const {amount, currency} = req.body as PaymentIntentData;

    if (!amount || !currency) {
      res.status(400).send("Missing required fields: amount or currency");
      return;
    }

    try {
      // ✅ Stripe initialized at runtime using secret
      const stripe = new Stripe(stripeSecret.value());

      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency,
        payment_method_types: ["card"],
      });

      res.status(200).send({
        clientSecret: paymentIntent.client_secret,
      });
    } catch (error) {
      logger.error("Stripe error", error);
      res.status(500).send("Failed to create PaymentIntent");
    }
  }
);
