import { describe, it, expect, beforeEach } from "vitest";
import { buffCV, principalCV, stringUtf8CV, uintCV } from "@stacks/transactions";

const ERR_NOT_AUTHORIZED = 100;
const ERR_INVALID_COURSE_HASH = 101;
const ERR_INVALID_PROFESSIONAL = 102;
const ERR_INVALID_CREDITS = 103;
const ERR_INVALID_DESCRIPTION = 108;
const ERR_INVALID_CATEGORY = 109;
const ERR_INVALID_EXPIRATION = 110;
const ERR_ISSUER_NOT_VERIFIED = 107;
const ERR_MAX_CREDITS_EXCEEDED = 112;
const ERR_AUTHORITY_NOT_SET = 114;
const ERR_INVALID_LOCATION = 117;
const ERR_INVALID_SIGNATURE = 120;
const ERR_TOKEN_ALREADY_EXISTS = 111;
const ERR_INVALID_STATUS = 116;
const ERR_USER_NOT_REGISTERED = 105;

interface CreditDetail {
  professional: string;
  courseHash: Buffer;
  credits: number;
  timestamp: number;
  description: string;
  category: string;
  expiration: number;
  status: boolean;
  location: string;
  provider: string;
}

interface UserCredits {
  totalCredits: number;
  tokenIds: number[];
}

interface Result<T> {
  ok: boolean;
  value: T;
}

class CreditIssuerMock {
  state: {
    lastTokenId: number;
    issuanceFee: number;
    authorityContract: string | null;
    maxCreditsPerUser: number;
    minCredits: number;
    creditDetails: Map<number, CreditDetail>;
    creditsByProfessional: Map<string, UserCredits>;
    approvedIssuers: Map<string, boolean>;
    signatures: Map<number, Buffer>;
  } = {
    lastTokenId: 0,
    issuanceFee: 100,
    authorityContract: null,
    maxCreditsPerUser: 100,
    minCredits: 1,
    creditDetails: new Map(),
    creditsByProfessional: new Map(),
    approvedIssuers: new Map(),
    signatures: new Map(),
  };
  blockHeight: number = 0;
  caller: string = "ST1TEST";
  stxTransfers: Array<{ amount: number; from: string; to: string | null }> = [];

  constructor() {
    this.reset();
  }

  reset() {
    this.state = {
      lastTokenId: 0,
      issuanceFee: 100,
      authorityContract: null,
      maxCreditsPerUser: 100,
      minCredits: 1,
      creditDetails: new Map(),
      creditsByProfessional: new Map(),
      approvedIssuers: new Map(),
      signatures: new Map(),
    };
    this.blockHeight = 0;
    this.caller = "ST1TEST";
    this.stxTransfers = [];
  }

  setAuthorityContract(contractPrincipal: string): Result<boolean> {
    if (this.state.authorityContract !== null) return { ok: false, value: ERR_AUTHORITY_NOT_SET };
    this.state.authorityContract = contractPrincipal;
    return { ok: true, value: true };
  }

  setIssuanceFee(newFee: number): Result<boolean> {
    if (!this.state.authorityContract) return { ok: false, value: ERR_AUTHORITY_NOT_SET };
    if (newFee < 0) return { ok: false, value: ERR_INVALID_FEE };
    this.state.issuanceFee = newFee;
    return { ok: true, value: true };
  }

  setMaxCreditsPerUser(newMax: number): Result<boolean> {
    if (!this.state.authorityContract) return { ok: false, value: ERR_AUTHORITY_NOT_SET };
    if (newMax <= 0) return { ok: false, value: ERR_INVALID_UPDATE };
    this.state.maxCreditsPerUser = newMax;
    return { ok: true, value: true };
  }

  approveIssuer(issuer: string): Result<boolean> {
    if (this.caller !== this.state.authorityContract) return { ok: false, value: ERR_NOT_AUTHORIZED };
    this.state.approvedIssuers.set(issuer, true);
    return { ok: true, value: true };
  }

  revokeIssuer(issuer: string): Result<boolean> {
    if (this.caller !== this.state.authorityContract) return { ok: false, value: ERR_NOT_AUTHORIZED };
    this.state.approvedIssuers.delete(issuer);
    return { ok: true, value: true };
  }

  issueCredit(
    professional: string,
    courseHash: Buffer,
    credits: number,
    description: string,
    category: string,
    expiration: number,
    location: string,
    signature: Buffer
  ): Result<number> {
    if (!this.state.approvedIssuers.get(this.caller)) return { ok: false, value: ERR_ISSUER_NOT_VERIFIED };
    if (professional === this.caller) return { ok: false, value: ERR_INVALID_PROFESSIONAL };
    if (courseHash.length !== 32) return { ok: false, value: ERR_INVALID_COURSE_HASH };
    if (credits < this.state.minCredits || credits > 1000) return { ok: false, value: ERR_INVALID_CREDITS };
    if (description.length === 0 || description.length > 256) return { ok: false, value: ERR_INVALID_DESCRIPTION };
    if (!["ethics", "technical", "management"].includes(category)) return { ok: false, value: ERR_INVALID_CATEGORY };
    if (expiration <= this.blockHeight) return { ok: false, value: ERR_INVALID_EXPIRATION };
    if (location.length > 100) return { ok: false, value: ERR_INVALID_LOCATION };
    if (signature.length !== 65) return { ok: false, value: ERR_INVALID_SIGNATURE };
    if (!this.state.authorityContract) return { ok: false, value: ERR_AUTHORITY_NOT_SET };
    const userCredits = this.state.creditsByProfessional.get(professional) || { totalCredits: 0, tokenIds: [] };
    if (userCredits.totalCredits + credits > this.state.maxCreditsPerUser) return { ok: false, value: ERR_MAX_CREDITS_EXCEEDED };

    this.stxTransfers.push({ amount: this.state.issuanceFee, from: this.caller, to: this.state.authorityContract });

    const tokenId = this.state.lastTokenId + 1;
    const detail: CreditDetail = {
      professional,
      courseHash,
      credits,
      timestamp: this.blockHeight,
      description,
      category,
      expiration,
      status: true,
      location,
      provider: this.caller,
    };
    this.state.creditDetails.set(tokenId, detail);
    this.state.signatures.set(tokenId, signature);
    this.state.creditsByProfessional.set(professional, {
      totalCredits: userCredits.totalCredits + credits,
      tokenIds: [...userCredits.tokenIds, tokenId],
    });
    this.state.lastTokenId = tokenId;
    return { ok: true, value: tokenId };
  }

  updateCreditStatus(tokenId: number, newStatus: boolean): Result<boolean> {
    const detail = this.state.creditDetails.get(tokenId);
    if (!detail) return { ok: false, value: ERR_TOKEN_ALREADY_EXISTS };
    if (detail.provider !== this.caller) return { ok: false, value: ERR_NOT_AUTHORIZED };
    if (detail.status === newStatus) return { ok: false, value: ERR_INVALID_STATUS };
    this.state.creditDetails.set(tokenId, { ...detail, status: newStatus });
    return { ok: true, value: true };
  }

  burnCredit(tokenId: number): Result<boolean> {
    const detail = this.state.creditDetails.get(tokenId);
    if (!detail) return { ok: false, value: ERR_TOKEN_ALREADY_EXISTS };
    if (detail.professional !== this.caller) return { ok: false, value: ERR_NOT_AUTHORIZED };
    this.state.creditDetails.delete(tokenId);
    this.state.signatures.delete(tokenId);
    const userCredits = this.state.creditsByProfessional.get(this.caller);
    if (!userCredits) return { ok: false, value: ERR_USER_NOT_REGISTERED };
    this.state.creditsByProfessional.set(this.caller, {
      totalCredits: userCredits.totalCredits - detail.credits,
      tokenIds: userCredits.tokenIds.filter(id => id !== tokenId),
    });
    return { ok: true, value: true };
  }

  transferCredit(tokenId: number, recipient: string): Result<boolean> {
    const detail = this.state.creditDetails.get(tokenId);
    if (!detail) return { ok: false, value: ERR_TOKEN_ALREADY_EXISTS };
    if (detail.professional !== this.caller) return { ok: false, value: ERR_NOT_AUTHORIZED };
    const senderCredits = this.state.creditsByProfessional.get(this.caller);
    if (!senderCredits) return { ok: false, value: ERR_USER_NOT_REGISTERED };
    const recipCredits = this.state.creditsByProfessional.get(recipient) || { totalCredits: 0, tokenIds: [] };
    this.state.creditDetails.set(tokenId, { ...detail, professional: recipient });
    this.state.creditsByProfessional.set(this.caller, {
      totalCredits: senderCredits.totalCredits - detail.credits,
      tokenIds: senderCredits.tokenIds.filter(id => id !== tokenId),
    });
    this.state.creditsByProfessional.set(recipient, {
      totalCredits: recipCredits.totalCredits + detail.credits,
      tokenIds: [...recipCredits.tokenIds, tokenId],
    });
    return { ok: true, value: true };
  }

  getCreditDetails(tokenId: number): CreditDetail | null {
    return this.state.creditDetails.get(tokenId) || null;
  }

  getCreditsByProfessional(professional: string): UserCredits | null {
    return this.state.creditsByProfessional.get(professional) || null;
  }

  isIssuerApproved(issuer: string): boolean {
    return this.state.approvedIssuers.get(issuer) || false;
  }

  getLastTokenId(): Result<number> {
    return { ok: true, value: this.state.lastTokenId };
  }

  verifySignature(tokenId: number, sig: Buffer): boolean {
    const storedSig = this.state.signatures.get(tokenId);
    return storedSig ? storedSig.equals(sig) : false;
  }

  getTotalCredits(professional: string): Result<number> {
    const credits = this.state.creditsByProfessional.get(professional);
    return { ok: true, value: credits ? credits.totalCredits : 0 };
  }
}

describe("CreditIssuer", () => {
  let contract: CreditIssuerMock;

  beforeEach(() => {
    contract = new CreditIssuerMock();
    contract.reset();
  });

  it("sets authority contract successfully", () => {
    const result = contract.setAuthorityContract("ST2TEST");
    expect(result.ok).toBe(true);
    expect(contract.state.authorityContract).toBe("ST2TEST");
  });

  it("approves issuer successfully", () => {
    contract.setAuthorityContract("ST1TEST");
    const result = contract.approveIssuer("ST3ISSUER");
    expect(result.ok).toBe(true);
    expect(contract.isIssuerApproved("ST3ISSUER")).toBe(true);
  });

  it("rejects issuance without approved issuer", () => {
    contract.setAuthorityContract("ST2AUTH");
    const courseHash = Buffer.alloc(32, 0);
    const signature = Buffer.alloc(65, 0);
    const result = contract.issueCredit(
      "ST4PROF",
      courseHash,
      10,
      "Course Description",
      "ethics",
      1000,
      "Online",
      signature
    );
    expect(result.ok).toBe(false);
    expect(result.value).toBe(ERR_ISSUER_NOT_VERIFIED);
  });

  it("gets last token id correctly", () => {
    const result = contract.getLastTokenId();
    expect(result.value).toBe(0);
  });
});