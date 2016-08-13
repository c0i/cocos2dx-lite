#include "BunnyMarkScene.h"
#include "MainScene.h"

USING_NS_CC;

bool BunnyMarkScene::init()
{
    if (!Scene::init()) { return false; }

    Size visibleSize = Director::getInstance()->getVisibleSize();
    Vec2 origin      = Director::getInstance()->getVisibleOrigin();

    countLabel = Label::createWithSystemFont("0", "sans", 32);
    countLabel->setPosition(visibleSize.width/2, visibleSize.height - countLabel->getContentSize().height - 10);
    addChild(countLabel, 999);

    bunnySprite = Sprite::create("wabbit_alpha.png");
    bunnySprite->retain();

    minX = origin.x;
    maxX = origin.x + visibleSize.width - bunnySprite->getContentSize().width;
    minY = origin.y;
    maxY = origin.y + visibleSize.height - bunnySprite->getContentSize().height;
    moreBunnies(100);

	auto size = Director::getInstance()->getOpenGLView()->getDesignResolutionSize();
	{
		auto clickTipsSprite = Sprite::create("res/click.png");
		clickTipsSprite->setPosition(size.width / 2, size.height - clickTipsSprite->getContentSize().height);
		addChild(clickTipsSprite, 1);
	}

	{
		auto label = Label::createWithSystemFont("BACK", "sans", 32);
		label->setAnchorPoint(Vec2(1, 1));
		label->setPosition(size.width, size.height);
		auto listener = EventListenerTouchOneByOne::create();
        listener->setSwallowTouches(true);
		listener->onTouchBegan = [](Touch *touch, Event *event) -> bool {
			if (event->getCurrentTarget()->getBoundingBox().containsPoint(touch->getLocation())) {
				Director::getInstance()->replaceScene(TransitionFade::create(0.5, MainScene::create()));
                return true;
            }
            return false;
		};

        Director::getInstance()->getEventDispatcher()->addEventListenerWithSceneGraphPriority(listener, label);
		addChild(label, 1);
	}

    return true;
}

void BunnyMarkScene::onEnter()
{
    Scene::onEnter();

    auto listener = EventListenerTouchOneByOne::create();
    listener->setSwallowTouches(true);

    listener->onTouchBegan = [](Touch *touch, Event *event) {
        return true;
    };

    listener->onTouchEnded = [=](Touch *touch, Event *event) {
        moreBunnies(100);
    };

    getEventDispatcher()->addEventListenerWithSceneGraphPriority(listener, this);

    scheduleUpdate();
}

void BunnyMarkScene::onExit()
{
    unscheduleUpdate();
    getEventDispatcher()->removeEventListenersForTarget(this, false);

    bunnySprite->release();
    bunnies.clear();

    Scene::onExit();
}

void BunnyMarkScene::update(float dt)
{
    Node::update(dt);

    for (auto bunny = bunnies.begin(); bunny != bunnies.end(); bunny++)
    {
        bunny->x += dt * bunny->xv;
        if (bunny->x < minX)
        {
            bunny->x = minX;
            bunny->xv = -bunny->xv;
        }
        if (bunny->x > maxX)
        {
            bunny->x = maxX;
            bunny->xv = -bunny->xv;
        }

        bunny->y += dt * bunny->yv;
        if (bunny->y < minY)
        {
            bunny->y = minY;
            bunny->yv = -bunny->yv;
        }
        if (bunny->y > maxY)
        {
            bunny->y = maxY;
            bunny->yv = -bunny->yv;
        }

        bunny->r = ((int) round(bunny->r + dt * bunny->rv)) % 360;

        bunny->sprite->setPosition(bunny->x, bunny->y);
        bunny->sprite->setRotation(bunny->r);
        bunny->sprite->setScale((float) (0.1f + fabs(sin(bunny->r * 3.14159265f / 180.0f))));
    }

    fpsTime += dt;
    fpsCount++;
    if (fpsTime > 1.0)
    {
        printf("%lu bunnies %.2f FPS\n", bunnies.size(), (fpsCount / fpsTime));
        fpsTime = 0;
        fpsCount = 0;
    }
}

int BunnyMarkScene::randomInt(int min, int max)
{
    return min + rand() % (max - min + 1);
}

void BunnyMarkScene::moreBunnies(int more)
{
    printf("BunnyMarkScene %p\n", this);

	Bunny2 bunny;

    for (int i = 0; i < more; i++)
    {
        initBunny(&bunny);
        bunnies.push_back(bunny);

        this->addChild(bunny.sprite);
    }

    countLabel->setString(utils::toString(bunnies.size()));
}

void BunnyMarkScene::initBunny(Bunny2 *bunny)
{
    bunny->sprite = Sprite::createWithSpriteFrame(bunnySprite->getSpriteFrame());

    bunny->x = minX + randomInt((int) minX, (int) maxX);
    bunny->y = minY + randomInt((int) minY, (int) maxY);

    do
    {
        bunny->xv = 100 - randomInt(0, 200);
    } while (bunny->xv < 10 && bunny->xv > -10);

    do
    {
        bunny->yv = 100 - randomInt(0, 200);
    } while (bunny->yv < 10 && bunny->yv > -10);

    bunny->r = randomInt(0, 360);

    do
    {
        bunny->rv = 50 - randomInt(0, 100);
    } while (bunny->rv < 10 && bunny->rv > -10);
}
