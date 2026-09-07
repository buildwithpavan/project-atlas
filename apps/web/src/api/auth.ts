import { post } from './client'
import type {
  AuthTokens,
  DataEnvelope,
  LoginParams,
  Organization,
  RegisterParams,
  User,
} from './types'

export interface RegisterResponse {
  user: User
  organization: Organization
}

export function register(params: RegisterParams): Promise<DataEnvelope<RegisterResponse>> {
  return post<DataEnvelope<RegisterResponse>>('/auth/register', params, { noAuth: true })
}

export function login(params: LoginParams): Promise<DataEnvelope<AuthTokens>> {
  return post<DataEnvelope<AuthTokens>>('/auth/login', params, { noAuth: true })
}

export function refresh(refreshToken: string): Promise<DataEnvelope<AuthTokens>> {
  return post<DataEnvelope<AuthTokens>>(
    '/auth/refresh',
    { refresh_token: refreshToken },
    { noAuth: true },
  )
}

export function logout(refreshToken: string): Promise<null> {
  return post<null>('/auth/logout', { refresh_token: refreshToken }, { noAuth: true })
}
