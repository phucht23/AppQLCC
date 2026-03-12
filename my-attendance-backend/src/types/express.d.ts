// src/types/express.d.ts
declare namespace Express {
  export interface Request {
    user?: {
      uid: string;
      email: string;
      role: string;
    };
  }
}