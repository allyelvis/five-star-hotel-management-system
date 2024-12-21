#!/bin/bash

# Exit if any command fails
set -e

# Project Variables
PROJECT_NAME="five-star-hotel-management"
DB_NAME="hotel_db"
DB_USER="hotel_admin"
DB_PASS="securepassword"
NODE_VERSION="18.2.0"
NEXT_VERSION="13.4.4"
PORT=3000

echo "🚀 Starting hotel management system setup..."

# Step 1: Install Required Software
echo "🔧 Installing Node.js, MongoDB, and dependencies..."
sudo apt update
sudo apt install -y nodejs npm mongodb git build-essential

# Step 2: Clone Project Repository
echo "📥 Cloning project repository..."
git clone https://github.com/username/$PROJECT_NAME.git
cd $PROJECT_NAME

# Step 3: Install Node.js Version Manager (nvm)
echo "🔄 Installing nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
source ~/.bashrc
nvm install $NODE_VERSION
nvm use $NODE_VERSION

# Step 4: Install Project Dependencies
echo "📦 Installing project dependencies..."
npm install

# Step 5: Setup Environment Variables
echo "🔑 Setting up environment variables..."
cat <<EOL > .env
DATABASE_URL=mongodb://localhost:27017/$DB_NAME
PORT=$PORT
STRIPE_SECRET_KEY=sk_test_example
EMAIL_USER=email@example.com
EMAIL_PASS=supersecret
JWT_SECRET=supersecurejwt
EOL

# Step 6: Setup MongoDB Database
echo "📊 Setting up MongoDB..."
sudo systemctl start mongod
mongo <<EOF
use $DB_NAME
db.createUser({ user: "$DB_USER", pwd: "$DB_PASS", roles: [{ role: "readWrite", db: "$DB_NAME" }] })
EOF

# Step 7: Setup Stripe Webhooks (Optional)
echo "💳 Configuring Stripe webhook (Optional, manual for now)..."
echo "Visit https://dashboard.stripe.com/webhooks to set up your webhook."

# Step 8: Build and Start Application
echo "⚙️ Building and starting the application..."
npm run build
npm run start &

# Step 9: Seed Database (Optional)
echo "🌱 Seeding database with sample data..."
node scripts/seed.js

# Step 10: PDF and Reporting Setup
echo "📝 Installing PDFKit for invoices and reports..."
npm install pdfkit file-saver

# Step 11: Add PDF Generation Utility
cat <<EOL > src/utils/pdfGenerator.ts
import PDFDocument from 'pdfkit';
export function generateInvoice({ guestName, reservationId, amount, date }) {
  const doc = new PDFDocument();
  const buffer = [];
  doc.on('data', (chunk) => buffer.push(chunk));
  doc.fontSize(24).text('Hotel Invoice', { align: 'center' });
  doc.text('Guest: ' + guestName);
  doc.text('Reservation ID: ' + reservationId);
  doc.text('Amount: $' + amount);
  doc.text('Date: ' + date);
  doc.end();
  return Buffer.concat(buffer);
}
EOL

# Step 12: Set Up Automated Reports API
cat <<EOL > src/pages/api/admin/reports.ts
import dbConnect from '../../../utils/dbConnect';
import Payment from '../../../server/models/Payment';
export default async function handler(req, res) {
  await dbConnect();
  const payments = await Payment.find().sort({ paymentDate: -1 });
  res.status(200).json(payments);
}
EOL

# Step 13: Setup Cron Job for Automated Reports
echo "🕒 Setting up cron job for automated report emails..."
(crontab -l ; echo "0 1 * * * cd ~/projects/$PROJECT_NAME && node scripts/sendReport.js") | crontab -

# Step 14: Create Systemd Service for Auto Restart
echo "⚡ Setting up systemd service for app restart on failure..."
sudo bash -c "cat > /etc/systemd/system/$PROJECT_NAME.service" <<EOF
[Unit]
Description=Hotel Management App
After=network.target

[Service]
ExecStart=/usr/bin/npm start --prefix /home/$USER/$PROJECT_NAME
Restart=always
User=$USER
Environment=NODE_ENV=production PORT=$PORT

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable $PROJECT_NAME
sudo systemctl start $PROJECT_NAME

echo "✅ Setup complete! Visit http://localhost:$PORT"