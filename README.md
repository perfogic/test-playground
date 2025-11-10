# ⚡ Solana Transaction Counter (NextJS + NestJS Monorepo)

A simple full-stack demo showing how to fetch and display **transaction counts from Solana blocks**.

- **Backend:** NestJS API (`apps/server`)
- **Frontend:** NextJS with React Query + TailwindCSS (`apps/client`)
- **Package manager:** pnpm (monorepo)

---

## 🧱 Project structure

```
├── apps/
│   ├── client/    # NextJS frontend
│   └── server/    # NestJS backend
├── pnpm-workspace.yaml
├── package.json
└── README.md
```

---

## ⚙️ Prerequisites

- Node.js >= 18
- pnpm >= 8

---

## 🧩 Environment setup

Before running the project, make sure you create the following environment files:

### 1️⃣ Backend – `apps/server/.env`

```
PORT=8000
## Just test rpc, don't care about api key
SOLANA_RPC=https://mainnet.helius-rpc.com/?api-key=7193b728-361b-45d0-903e-50f7ee878fbc
FALLBACK_SOLANA_RPC=https://api.mainnet-beta.solana.com
```

### 2️⃣ Frontend – `apps/client/.env.local`

```
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
```

---

## 🚀 Run the project locally

### 1️⃣ Install dependencies

From the root folder:

```
pnpm install
```

### 2️⃣ Start the backend (NestJS)

```
pnpm --filter server start
```

> Runs on [http://localhost:8000](http://localhost:8000)

Test manually:

    curl http://localhost:8000/solana/tx-count?block=357262054

### 3️⃣ Start the frontend (NextJS)

```
pnpm --filter client dev
```

> Runs on [http://localhost:3000](http://localhost:3000)

---

## ✅ Expected flow

1. Enter a Solana block number in the frontend.
2. The frontend calls the backend API:  
   `GET /solana/tx-count?block=<block_number>`
3. The backend queries Solana RPC and responds:

   {
   "blockNumber": 357262054,
   "transactionCount": 1450
   }

---

## 🧪 Testing (optional)

Inside `apps/server`, run Jest tests:

```
pnpm test
```

---

## 👨‍💻 Author

Built by **Phạm Minh Đăng (Perfogic)**
