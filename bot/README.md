# PXHB Discord Bot - Railway Deployment

This repository is pre-configured for deployment to **Railway**.

## 🚀 Quick Start

1. Create a new project on [Railway](https://railway.app/).
2. Select **"Deploy from GitHub repo"**.
3. Choose this repository.

## ⚙️ Configuration (Variables)

You **MUST** set the following variables in the Railway **Variables** tab:

| Variable | Description |
| :--- | :--- |
| `DISCORD_TOKEN` | Your Discord Bot Token from the Developer Portal. |
| `PORT` | Set this to `8080` (Railway often provides this automatically). |

## ⚠️ Important Discord Setup

For role management to work, you must:
1. Go to the [Discord Developer Portal](https://discord.com/developers/applications).
2. Select your Bot -> **Bot** tab.
3. Scroll down to **Privileged Gateway Intents**.
4. Enable **Server Members Intent**.

## 📁 Persistent Storage (Optional)

SQLite databases on Railway are ephemeral (they reset on restart). To save keys permanently:
1. Go to your Railway service **Settings**.
2. Add a **Volume** (Mount Path: `/app/`).
3. This ensures `licenses.db` is saved between deployments.
