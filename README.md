# 📚 On-Chain Continuing Education Credit Tracker

Welcome to a decentralized solution for tracking continuing education credits (CECs) on the blockchain! This project empowers professionals (like doctors, lawyers, and engineers) to securely record, verify, and manage their required education credits for license renewals. Using the Stacks blockchain and Clarity smart contracts, it eliminates fraud, lost records, and centralized dependencies, ensuring immutable proof of professional development.

## ✨ Features

🔒 Immutable on-chain storage of education credits  
📈 Track accumulated credits per professional category  
🏅 Issue verifiable NFTs for completed courses  
✅ Instant verification by employers or licensing boards  
🛡️ Fraud prevention through unique hashes and signatures  
📊 Reporting tools for renewal compliance  
🤝 Multi-party involvement: issuers, professionals, and verifiers  
🔄 Transferable credits (e.g., for cross-jurisdiction recognition)  
⚙️ Governance for updating standards and resolving disputes  

## 🛠 How It Works

This system is built with 8 interconnected Clarity smart contracts for modularity, security, and scalability. Each contract handles a specific aspect of the CEC lifecycle, from registration to verification.

### Key Smart Contracts
1. **UserRegistry.clar**: Registers professionals and education providers (issuers) with unique IDs, KYC hashes, and roles.  
2. **CourseCatalog.clar**: Manages a registry of approved courses, including details like duration, credits awarded, and prerequisites.  
3. **CreditIssuer.clar**: Allows verified issuers to mint NFTs representing completed credits, linked to course hashes and timestamps.  
4. **CreditAccumulator.clar**: Tracks and aggregates credits for each professional, calculating totals by category (e.g., ethics, technical).  
5. **VerificationEngine.clar**: Provides read-only functions to verify credit authenticity, ownership, and totals without revealing sensitive data.  
6. **RenewalManager.clar**: Integrates with licensing logic to flag renewal eligibility based on accumulated credits and expiration dates.  
7. **DisputeResolver.clar**: Handles challenges to issued credits, with voting mechanisms for governance participants.  
8. **GovernanceToken.clar**: Issues governance tokens (STX-based) for system updates, like adding new course categories or blacklisting issuers.

**For Professionals**  
- Register via UserRegistry with your professional ID and a hash of your license.  
- Enroll in a course from CourseCatalog.  
- Upon completion, the issuer calls CreditIssuer to mint an NFT credit to your address.  
- Use CreditAccumulator to view your total credits and RenewalManager to check compliance status.  

Boom! Your credits are now tamper-proof and always accessible.

**For Education Providers (Issuers)**  
- Register as an issuer in UserRegistry.  
- Add courses to CourseCatalog with credit values.  
- After a professional completes a course, issue credits via CreditIssuer, including a unique completion hash.  

That's it! Secure issuance with on-chain accountability.

**For Verifiers (e.g., Employers or Boards)**  
- Query VerificationEngine with a professional's address to confirm credits.  
- Use DisputeResolver if discrepancies arise.  

Instant, trustless verification without intermediaries.
