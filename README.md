# Auction Smart Contract

Este proyecto implementa un contrato inteligente de subasta en Solidity con las siguientes características:

- Registro de ofertas con historial completo.
- Extensión automática del tiempo si una oferta es recibida cerca del final.
- Reembolso parcial durante la subasta.
- Distribución de fondos al finalizar con comisión del 2%.

## Detalles técnicos

- Versión de Solidity: ^0.8.20
- Licencia: MIT
- Autor: Gabriel Romero

## Cómo usar

1. Despliega el contrato en Remix u otro entorno compatible.
2. Ejecuta la función `bid()` para ofertar.
3. El propietario puede finalizar la subasta con `endAuction()`.
4. Los usuarios pueden usar `partialRefund()` para retirar el exceso.

## Eventos

- `NewBid`: Se emite cuando un usuario realiza una oferta válida.
- `AuctionEnded`: Se emite al finalizar la subasta.

## Licencia

MIT
