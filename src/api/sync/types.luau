export type config = {
    experience: {
        id: number,
        badges: { [string]: badge_settings }?,
        passes: { [string]: gamepass_settings }?,
        products: { [string]: product_settings }?,
    }
}

export type badge_settings = {
    name: string,
    description: string,
    icon: string,
    enabled: boolean?,
}

export type gamepass_settings = {
    name: string,
    description: string,
    icon: string,
    price: number?,
}

export type product_settings = {
    name: string,
    description: string,
    icon: string,
    price: number,
    metadata: { [string]: any }?,
}

return nil