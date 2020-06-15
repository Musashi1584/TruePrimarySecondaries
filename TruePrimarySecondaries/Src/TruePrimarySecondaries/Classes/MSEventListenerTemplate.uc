class MSEventListenerTemplate extends X2EventListenerTemplate;

function RegisterForEvents()
{
	// Hack in here to start the actor as early as possible in tactical game
	`XCOMGAME.Spawn(class'TruePrimarySecondaries.DropShipMatinee_Actor');
}