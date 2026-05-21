# How to publish this repo on GitHub

A practical step-by-step for first-time pushers.

## 1 · Install Git (if you don't have it)

Download from [git-scm.com/download/win](https://git-scm.com/download/win).
During installation accept all defaults.

Verify:
```bash
git --version
```

## 2 · Configure your identity (one time only)

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

Use the same email your GitHub account uses.

## 3 · Create the empty repository on GitHub

1. Go to [github.com](https://github.com) → top-right `+` → **New repository**
2. Repository name: `sql-powerbi-portfolio`
3. Description: `End-to-end BI portfolio: SQL Server + Power BI on a synthetic water-distribution dataset`
4. Visibility: **Public** (necessary if you want recruiters to find it)
5. **Do NOT** initialize with README, .gitignore, or LICENSE — we already have those
6. Click **Create repository**

GitHub will show you a page with setup commands. Keep that tab open.

## 4 · Push from your local folder

Open a terminal inside the extracted repo folder (the one containing this file).

```bash
git init
git add .
git commit -m "Initial commit: synthetic data, docs, repo structure"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/sql-powerbi-portfolio.git
git push -u origin main
```

Replace `YOUR_USERNAME` with your actual GitHub username.

If GitHub asks for credentials, use a **personal access token** instead of your
password. Generate one at: github.com → Settings → Developer settings → Personal
access tokens → Tokens (classic) → Generate new token → tick `repo` scope.

## 5 · Verify

Refresh the GitHub repo page. You should see all your files. The README will
render on the landing page.

## 6 · Recommended next steps (in priority order)

| Priority | Task |
|---|---|
| 1 | Update `Author` section in both READMEs with your real LinkedIn and email |
| 2 | Add 2–3 anonymized Power BI dashboard screenshots to `powerbi/screenshots/` |
| 3 | Migrate your real SQL queries into the corresponding `sql/0X_*` folders |
| 4 | Add module-level READMEs explaining the business logic for modules 2–8 |
| 5 | Export Power BI measures (`Tabular Editor` → File → Export → DAX script) to `powerbi/measures.dax` |
| 6 | Pin the repo on your GitHub profile (Profile → Customize your pins) |

## Adding new files later

After making changes locally:

```bash
git add .
git commit -m "Add retention module queries"
git push
```

That's it. The changes show up on GitHub immediately.
